import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_option.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_protocol.dart';

void main() {
  late TelnetProtocol protocol;

  setUp(() {
    protocol = TelnetProtocol();
  });

  group('TelnetProtocol', () {
    test('passes through plain text as TelnetDataEvent', () {
      final input = Uint8List.fromList('Hello, World!\r\n'.codeUnits);
      final events = protocol.processBytes(input);

      expect(events, hasLength(1));
      expect(events.first, isA<TelnetDataEvent>());
      final data = (events.first as TelnetDataEvent).data;
      expect(String.fromCharCodes(data), 'Hello, World!\r\n');
    });

    test('handles empty input', () {
      final events = protocol.processBytes(Uint8List(0));
      expect(events, isEmpty);
    });

    test('parses IAC WILL option', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.will, TelnetOpt.sga,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(1));
      expect(events.first, isA<TelnetNegotiationEvent>());
      final neg = events.first as TelnetNegotiationEvent;
      expect(neg.command, TelnetCmd.will);
      expect(neg.option, TelnetOpt.sga);
    });

    test('parses IAC DO option', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.doOpt, TelnetOpt.naws,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(1));
      final neg = events.first as TelnetNegotiationEvent;
      expect(neg.command, TelnetCmd.doOpt);
      expect(neg.option, TelnetOpt.naws);
    });

    test('parses IAC WONT and IAC DONT', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.wont, TelnetOpt.echo,
        TelnetCmd.iac, TelnetCmd.dont, TelnetOpt.ttype,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(2));
      expect((events[0] as TelnetNegotiationEvent).command, TelnetCmd.wont);
      expect((events[1] as TelnetNegotiationEvent).command, TelnetCmd.dont);
    });

    test('handles IAC IAC escape as literal 0xFF byte', () {
      final input = Uint8List.fromList([
        0x41, // 'A'
        TelnetCmd.iac, TelnetCmd.iac, // escaped 0xFF
        0x42, // 'B'
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(1));
      final data = (events.first as TelnetDataEvent).data;
      expect(data, [0x41, 0xFF, 0x42]);
    });

    test('parses Go Ahead command', () {
      final input = Uint8List.fromList([
        0x48, 0x69, // "Hi"
        TelnetCmd.iac, TelnetCmd.ga,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(2));
      expect(events[0], isA<TelnetDataEvent>());
      expect(events[1], isA<TelnetCommandEvent>());
      expect((events[1] as TelnetCommandEvent).command, TelnetCmd.ga);
    });

    test('parses subnegotiation', () {
      // IAC SB TTYPE SEND IAC SE
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
        TtypeSub.send,
        TelnetCmd.iac, TelnetCmd.se,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(1));
      expect(events.first, isA<TelnetSubnegotiationEvent>());
      final subneg = events.first as TelnetSubnegotiationEvent;
      expect(subneg.option, TelnetOpt.ttype);
      expect(subneg.data, [TtypeSub.send]);
    });

    test('handles mixed data and negotiations', () {
      final input = Uint8List.fromList([
        ...'Welcome'.codeUnits,
        TelnetCmd.iac, TelnetCmd.will, TelnetOpt.echo,
        ...' to AA!'.codeUnits,
      ]);
      final events = protocol.processBytes(input);

      expect(events, hasLength(3));
      expect(events[0], isA<TelnetDataEvent>());
      expect(String.fromCharCodes((events[0] as TelnetDataEvent).data),
          'Welcome');
      expect(events[1], isA<TelnetNegotiationEvent>());
      expect(events[2], isA<TelnetDataEvent>());
      expect(String.fromCharCodes((events[2] as TelnetDataEvent).data),
          ' to AA!');
    });

    test('handles data split across multiple chunks', () {
      final chunk1 = Uint8List.fromList([TelnetCmd.iac]);
      final chunk2 = Uint8List.fromList([TelnetCmd.will, TelnetOpt.sga]);

      final events1 = protocol.processBytes(chunk1);
      expect(events1, isEmpty); // IAC is pending

      final events2 = protocol.processBytes(chunk2);
      expect(events2, hasLength(1));
      expect(events2.first, isA<TelnetNegotiationEvent>());
    });

    test('reset clears parser state', () {
      // Start a negotiation but don't complete it.
      protocol.processBytes(Uint8List.fromList([TelnetCmd.iac]));
      protocol.reset();

      // After reset, should parse normally.
      final events = protocol.processBytes(
        Uint8List.fromList('test'.codeUnits),
      );
      expect(events, hasLength(1));
      expect(events.first, isA<TelnetDataEvent>());
    });
  });

  group('TelnetProtocol static builders', () {
    test('buildWill creates correct bytes', () {
      final bytes = TelnetProtocol.buildWill(TelnetOpt.naws);
      expect(bytes, [TelnetCmd.iac, TelnetCmd.will, TelnetOpt.naws]);
    });

    test('buildNaws creates correct subnegotiation', () {
      final bytes = TelnetProtocol.buildNaws(80, 24);
      expect(bytes, [
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.naws,
        0, 80, 0, 24,
        TelnetCmd.iac, TelnetCmd.se,
      ]);
    });

    test('buildTtypeIs creates correct subnegotiation', () {
      final bytes = TelnetProtocol.buildTtypeIs('XTERM');
      expect(bytes, [
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
        TtypeSub.is_,
        ...('XTERM'.codeUnits),
        TelnetCmd.iac, TelnetCmd.se,
      ]);
    });

    test('buildWont creates correct bytes', () {
      final bytes = TelnetProtocol.buildWont(TelnetOpt.echo);
      expect(bytes, [TelnetCmd.iac, TelnetCmd.wont, TelnetOpt.echo]);
    });

    test('buildDo creates correct bytes', () {
      final bytes = TelnetProtocol.buildDo(TelnetOpt.sga);
      expect(bytes, [TelnetCmd.iac, TelnetCmd.doOpt, TelnetOpt.sga]);
    });

    test('buildDont creates correct bytes', () {
      final bytes = TelnetProtocol.buildDont(TelnetOpt.ttype);
      expect(bytes, [TelnetCmd.iac, TelnetCmd.dont, TelnetOpt.ttype]);
    });
  });

  group('TelnetProtocol - additional command events', () {
    test('parses EOR command', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.eor,
      ]);
      final events = protocol.processBytes(input);
      expect(events, hasLength(1));
      expect(events.first, isA<TelnetCommandEvent>());
      expect((events.first as TelnetCommandEvent).command, TelnetCmd.eor);
    });

    test('parses NOP command', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.nop,
      ]);
      final events = protocol.processBytes(input);
      expect(events, hasLength(1));
      expect((events.first as TelnetCommandEvent).command, TelnetCmd.nop);
    });

    test('parses AYT command', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.ayt,
      ]);
      final events = protocol.processBytes(input);
      expect(events, hasLength(1));
      expect((events.first as TelnetCommandEvent).command, TelnetCmd.ayt);
    });

    test('parses BRK, IP, AO, EC, EL commands', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.brk,
        TelnetCmd.iac, TelnetCmd.ip,
        TelnetCmd.iac, TelnetCmd.ao,
        TelnetCmd.iac, TelnetCmd.ec,
        TelnetCmd.iac, TelnetCmd.el,
      ]);
      final events = protocol.processBytes(input);
      expect(events, hasLength(5));
      expect((events[0] as TelnetCommandEvent).command, TelnetCmd.brk);
      expect((events[1] as TelnetCommandEvent).command, TelnetCmd.ip);
      expect((events[2] as TelnetCommandEvent).command, TelnetCmd.ao);
      expect((events[3] as TelnetCommandEvent).command, TelnetCmd.ec);
      expect((events[4] as TelnetCommandEvent).command, TelnetCmd.el);
    });
  });

  group('TelnetProtocol - subnegotiation edge cases', () {
    test('handles escaped IAC inside subnegotiation data', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
        0x01,
        TelnetCmd.iac, TelnetCmd.iac, // escaped 0xFF
        0x02,
        TelnetCmd.iac, TelnetCmd.se,
      ]);
      final events = protocol.processBytes(input);
      expect(events, hasLength(1));
      final subneg = events.first as TelnetSubnegotiationEvent;
      expect(subneg.option, TelnetOpt.ttype);
      expect(subneg.data, [0x01, 0xFF, 0x02]);
    });

    test('handles subneg split across two chunks', () {
      final chunk1 = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
        TtypeSub.send,
      ]);
      final chunk2 = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.se,
      ]);

      final events1 = protocol.processBytes(chunk1);
      expect(events1, isEmpty);

      final events2 = protocol.processBytes(chunk2);
      expect(events2, hasLength(1));
      final subneg = events2.first as TelnetSubnegotiationEvent;
      expect(subneg.option, TelnetOpt.ttype);
      expect(subneg.data, [TtypeSub.send]);
    });

    test('handles malformed subneg (IAC followed by unexpected byte)', () {
      final input = Uint8List.fromList([
        TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
        0x41, // 'A' data
        TelnetCmd.iac, 0x42, // malformed: IAC + non-SE/non-IAC byte
      ]);
      final events = protocol.processBytes(input);
      // Should emit subneg with data [0x41], then re-process 0x42 as normal data
      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.first, isA<TelnetSubnegotiationEvent>());
      final subneg = events.first as TelnetSubnegotiationEvent;
      expect(subneg.data, [0x41]);
      if (events.length > 1) {
        expect(events[1], isA<TelnetDataEvent>());
        expect((events[1] as TelnetDataEvent).data, [0x42]);
      }
    });
  });
}
