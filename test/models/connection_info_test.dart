import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/connection_info.dart';

void main() {
  group('ConnectionInfo', () {
    test('ancientAnguish constant has correct host and port', () {
      expect(ConnectionInfo.ancientAnguish.host, 'ancient.anguish.org');
      expect(ConnectionInfo.ancientAnguish.port, 2222);
      expect(ConnectionInfo.ancientAnguish.name, 'Ancient Anguish');
    });

    test('toString formats as "name (host:port)"', () {
      const info = ConnectionInfo(
        name: 'TestMUD',
        host: 'example.com',
        port: 4000,
      );
      expect(info.toString(), 'TestMUD (example.com:4000)');
    });

    test('ConnectionStatus enum has all expected values', () {
      expect(ConnectionStatus.values, hasLength(5));
      expect(
        ConnectionStatus.values.map((v) => v.name),
        containsAll([
          'disconnected',
          'connecting',
          'connected',
          'disconnecting',
          'error',
        ]),
      );
    });

    test('custom ConnectionInfo preserves fields', () {
      const info = ConnectionInfo(
        name: 'Custom',
        host: '192.168.1.1',
        port: 9999,
      );
      expect(info.name, 'Custom');
      expect(info.host, '192.168.1.1');
      expect(info.port, 9999);
    });
  });
}
