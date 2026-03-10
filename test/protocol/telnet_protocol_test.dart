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
  });
}
