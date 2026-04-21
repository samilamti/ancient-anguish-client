// Raw Telnet capture tool for investigating how the AA server sends prompts.
//
// Opens a plain TCP connection to ancient.anguish.org:2222, logs every inbound
// byte (hex + printable, with IAC commands annotated) to /tmp/aa_wire.log, and
// forwards stdin to the server so the session can be driven from the terminal.
//
// Usage:
//   dart run scripts/dev/telnet_capture.dart
//   dart run scripts/dev/telnet_capture.dart some.other.host 1234

import 'dart:convert';
import 'dart:io';

const _defaultHost = 'ancient.anguish.org';
const _defaultPort = 2222;
const _logPath = '/tmp/aa_wire.log';

// Telnet command bytes (subset; matches lib/protocol/telnet/telnet_option.dart).
const _iac = 255;
const _dont = 254;
const _doOpt = 253;
const _wont = 252;
const _will = 251;
const _sb = 250;
const _ga = 249;
const _se = 240;
const _eor = 239;
const _nop = 241;

String _cmdName(int b) => switch (b) {
      _iac => 'IAC',
      _dont => 'DONT',
      _doOpt => 'DO',
      _wont => 'WONT',
      _will => 'WILL',
      _sb => 'SB',
      _ga => 'GA',
      _se => 'SE',
      _eor => 'EOR',
      _nop => 'NOP',
      _ => 'CMD=$b',
    };

String _optName(int o) => switch (o) {
      1 => 'ECHO',
      3 => 'SGA',
      24 => 'TTYPE',
      25 => 'EOR',
      31 => 'NAWS',
      86 => 'MCCP2',
      87 => 'MCCP3',
      201 => 'GMCP',
      _ => 'opt=$o',
    };

void main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : _defaultHost;
  final port = args.length > 1 ? int.parse(args[1]) : _defaultPort;

  final logFile = File(_logPath);
  final log = logFile.openWrite();
  log.writeln('# Capture started ${DateTime.now()} to $host:$port');

  void write(String line) {
    final stamped = '[${_ts()}] $line';
    log.writeln(stamped);
    stderr.writeln(stamped);
  }

  write('connecting…');
  final socket = await Socket.connect(host, port);
  write('connected: ${socket.remoteAddress.address}:${socket.remotePort}');

  final incoming = _IncomingDecoder(write);

  socket.listen(
    (chunk) {
      incoming.feed(chunk);
      stdout.add(_stripIac(chunk));
    },
    onError: (err) => write('socket error: $err'),
    onDone: () {
      write('socket closed by peer');
      log.close();
      exit(0);
    },
  );

  // Forward stdin (line-buffered) to the server. Echo our own sends to the log.
  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    write('-> ${jsonEncode(line)}');
    socket.add(utf8.encode('$line\r\n'));
  }, onDone: () {
    write('stdin closed, closing socket');
    socket.destroy();
    log.close();
    exit(0);
  });
}

String _ts() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
}

/// Removes IAC sequences from [chunk] so the echoed stream is clean text.
List<int> _stripIac(List<int> chunk) {
  final out = <int>[];
  var i = 0;
  while (i < chunk.length) {
    final b = chunk[i];
    if (b != _iac) {
      out.add(b);
      i++;
      continue;
    }
    if (i + 1 >= chunk.length) break;
    final cmd = chunk[i + 1];
    if (cmd == _iac) {
      // Escaped IAC — emit one 0xFF.
      out.add(0xFF);
      i += 2;
    } else if (cmd == _will || cmd == _wont || cmd == _doOpt || cmd == _dont) {
      i += 3; // IAC + cmd + option
    } else if (cmd == _sb) {
      // Skip to IAC SE.
      i += 2;
      while (i < chunk.length - 1 &&
          !(chunk[i] == _iac && chunk[i + 1] == _se)) {
        i++;
      }
      i += 2;
    } else {
      i += 2;
    }
  }
  return out;
}

/// Turns raw inbound bytes into annotated log lines.
class _IncomingDecoder {
  _IncomingDecoder(this.write);

  final void Function(String line) write;
  final _pending = <int>[];

  void feed(List<int> chunk) {
    var i = 0;
    while (i < chunk.length) {
      final b = chunk[i];
      if (b == _iac) {
        _flushText();
        final remaining = chunk.sublist(i);
        final consumed = _logIac(remaining);
        i += consumed;
        continue;
      }
      _pending.add(b);
      i++;
    }
    _flushText();
  }

  int _logIac(List<int> buf) {
    if (buf.length < 2) return buf.length;
    final cmd = buf[1];
    if (cmd == _will || cmd == _wont || cmd == _doOpt || cmd == _dont) {
      if (buf.length < 3) return buf.length;
      write('<- IAC ${_cmdName(cmd)} ${_optName(buf[2])}');
      return 3;
    }
    if (cmd == _sb) {
      // Scan to IAC SE.
      var end = 2;
      while (end < buf.length - 1 && !(buf[end] == _iac && buf[end + 1] == _se)) {
        end++;
      }
      final option = buf.length > 2 ? buf[2] : 0;
      final data = buf.sublist(3, end);
      write('<- IAC SB ${_optName(option)} ${_hex(data)} IAC SE');
      return end + 2;
    }
    write('<- IAC ${_cmdName(cmd)}');
    return 2;
  }

  void _flushText() {
    if (_pending.isEmpty) return;
    final bytes = List<int>.from(_pending);
    _pending.clear();
    final text = utf8.decode(bytes, allowMalformed: true);
    final hex = _hex(bytes);
    write('<- ${jsonEncode(text)}  [$hex]');
  }

  String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
