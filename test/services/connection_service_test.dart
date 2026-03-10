import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/connection_info.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';

void main() {
  late ConnectionService service;

  setUp(() {
    service = ConnectionService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('ConnectionService - Lifecycle', () {
    test('starts disconnected', () {
      expect(service.status, ConnectionStatus.disconnected);
      expect(service.isConnected, false);
      expect(service.connectionInfo, isNull);
    });

    test('disconnect while disconnected is a no-op', () async {
      await service.disconnect();
      expect(service.status, ConnectionStatus.disconnected);
    });

    test('concurrent disconnect calls are safe', () async {
      await Future.wait([
        service.disconnect(),
        service.disconnect(),
      ]);
      expect(service.status, ConnectionStatus.disconnected);
    });

    test('connect to unreachable host transitions to error', () async {
      const badInfo = ConnectionInfo(
        name: 'Test',
        host: '192.0.2.1',
        port: 1,
      );
      await service.connect(badInfo);
      // Should be error, not stuck in connecting.
      expect(
        service.status,
        anyOf(ConnectionStatus.error, ConnectionStatus.disconnected),
      );
    });

    test('connect while connecting is a no-op', () async {
      const badInfo = ConnectionInfo(
        name: 'Test',
        host: '192.0.2.1',
        port: 1,
      );
      final f1 = service.connect(badInfo);
      // Second connect should return immediately (status is connecting).
      final f2 = service.connect(badInfo);
      await Future.wait([f1, f2]);
      // Should not have corrupted state.
      expect(service.status, isNot(ConnectionStatus.connecting));
    });
  });

  group('ConnectionService - Command Safety', () {
    test('sendCommand while disconnected is safe', () {
      // Should not throw.
      service.sendCommand('test');
    });

    test('sendBytes while disconnected is safe', () {
      // Should not throw.
      service.sendBytes(Uint8List.fromList([0xFF, 0xFB, 0x01]));
    });
  });
}
