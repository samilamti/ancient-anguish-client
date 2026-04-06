// ignore_for_file: avoid_print
// Self-contained test: connect to MUD, handle telnet protocol,
// strip ANSI, and test prompt regex. No Flutter imports.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

final promptRegex =
    RegExp(r'^(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(-?\d+)\s+(-?\d+)$');

final ansiRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

const iac = 0xFF, will = 0xFB, wont = 0xFC, doCmd = 0xFD, dont = 0xFE;
const sb = 0xFA, se = 0xF0, gaCmd = 0xF9, eor = 0xEF;
const naws = 31, ttype = 24, sga = 3, echo = 1;

var phase = 0; // 0=name, 1=password, 2=logged in
var promptSent = false;
var commandsSent = false;
final dataBuffer = <int>[];

late Socket socket;

void main() async {
  print('Connecting to ancient.anguish.org:2222...');
  socket = await Socket.connect('ancient.anguish.org', 2222);
  print('Connected!\n');

  socket.listen(
    (rawData) {
      var i = 0;
      while (i < rawData.length) {
        if (rawData[i] == iac && i + 1 < rawData.length) {
          final cmd = rawData[i + 1];
          if (cmd == iac) {
            dataBuffer.add(0xFF);
            i += 2;
          } else if (cmd >= will && cmd <= dont) {
            _flushNewlineLines();
            _handleNeg(cmd, i + 2 < rawData.length ? rawData[i + 2] : 0);
            i += 3;
          } else if (cmd == sb) {
            _flushNewlineLines();
            i += 2;
            while (i < rawData.length - 1) {
              if (rawData[i] == iac && rawData[i + 1] == se) { i += 2; break; }
              i++;
            }
          } else if (cmd == gaCmd || cmd == eor) {
            _flushNewlineLines();
            _flushGaLine();
            i += 2;
          } else {
            i += 2;
          }
        } else {
          dataBuffer.add(rawData[i]);
          i++;
        }
      }
      _flushNewlineLines();
      _checkPending();
    },
    onDone: () { print('\nConnection closed.'); exit(0); },
    onError: (e) { print('Error: $e'); exit(1); },
  );
}

void _flushNewlineLines() {
  while (true) {
    final nl = dataBuffer.indexOf(0x0A);
    if (nl < 0) break;
    final lineBytes = dataBuffer.sublist(0, nl);
    dataBuffer.removeRange(0, nl + 1);
    final stripped = _strip(lineBytes);
    if (stripped.isEmpty) continue;
    print('  [LINE] |$stripped|');
    _testRegex(stripped, 'newline');
    _handleOutput(stripped);
  }
}

void _flushGaLine() {
  if (dataBuffer.isEmpty) return;
  final stripped = _strip(dataBuffer);
  dataBuffer.clear();
  if (stripped.isEmpty) { print('  [GA] (empty)'); return; }
  print('  [GA LINE] |$stripped|');
  _testRegex(stripped, 'GA');
  _handleOutput(stripped);
}

void _checkPending() {
  if (dataBuffer.isEmpty) return;
  final stripped = _strip(dataBuffer);
  if (stripped.isNotEmpty) {
    print('  [PENDING] |$stripped|');
    _handleOutput(stripped);
  }
}

String _strip(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true)
      .replaceAll(ansiRegex, '')
      .replaceAll('\r', '')
      .trim();
}

void _testRegex(String stripped, String source) {
  if (!promptSent) return;
  final match = promptRegex.firstMatch(stripped);
  if (match != null) {
    print('  *** PROMPT MATCHED ($source)! ***');
    print('    HP=${match.group(1)} MaxHP=${match.group(2)} '
        'SP=${match.group(3)} MaxSP=${match.group(4)} '
        'X=${match.group(5)} Y=${match.group(6)}');
  }
}

void _handleOutput(String text) {
  if (phase == 0 && text.contains('name')) {
    print('\n>>> SENDING: chosen');
    socket.add(utf8.encode('chosen\r\n'));
    phase = 1;
  }
  if (phase == 1 && text.contains('Password')) {
    print('\n>>> SENDING: vinter');
    socket.add(utf8.encode('vinter\r\n'));
    phase = 2;
  }
  if (phase == 2 && text.contains('already playing')) {
    print('\n>>> SENDING: y (kick other copy)');
    socket.add(utf8.encode('y\r\n'));
  }
  if (phase == 2 && !promptSent && (text.contains('Welcome back') || text.contains('A player usage graph'))) {
    _sendPromptAndCommands();
  }
  // Also trigger on first GA prompt after login (may already have prompt set from before).
  if (phase == 2 && !promptSent && promptRegex.hasMatch(text)) {
    print('  [Prompt already active from previous session]');
    promptSent = true;
    _sendCommands();
  }
}

void _sendPromptAndCommands() {
  if (promptSent) return;
  Future.delayed(Duration(seconds: 1), () {
    print('\n>>> SENDING: prompt set command');
    socket.add(utf8.encode(
        'prompt set |HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD| |SPACE|\r\n'));
    promptSent = true;
    _sendCommands();
  });
}

void _sendCommands() {
  if (commandsSent) return;
  commandsSent = true;
  Future.delayed(Duration(seconds: 2), () {
    print('\n>>> SENDING: look');
    socket.add(utf8.encode('look\r\n'));
  });
  Future.delayed(Duration(seconds: 5), () {
    print('\n>>> SENDING: north');
    socket.add(utf8.encode('north\r\n'));
  });
  Future.delayed(Duration(seconds: 8), () {
    print('\n>>> SENDING: south');
    socket.add(utf8.encode('south\r\n'));
  });
  Future.delayed(Duration(seconds: 11), () {
    print('\n>>> SENDING: quit / y');
    socket.add(utf8.encode('quit\r\n'));
    Future.delayed(Duration(milliseconds: 500), () {
      socket.add(utf8.encode('y\r\n'));
    });
    Future.delayed(Duration(seconds: 2), () => exit(0));
  });
}

void _handleNeg(int cmd, int option) {
  if (cmd == doCmd) {
    switch (option) {
      case naws:
        socket.add([iac, will, naws, iac, sb, naws, 0, 120, 0, 40, iac, se]);
      case ttype: socket.add([iac, will, ttype]);
      case sga: socket.add([iac, will, sga]);
      default: socket.add([iac, wont, option]);
    }
  } else if (cmd == will) {
    switch (option) {
      case sga: socket.add([iac, doCmd, sga]);
      case echo: socket.add([iac, doCmd, echo]);
      default: socket.add([iac, dont, option]);
    }
  }
}
