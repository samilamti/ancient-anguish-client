import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/background/area_background_manager.dart';

void main() {
  late AreaBackgroundManager manager;

  setUp(() {
    manager = AreaBackgroundManager();
  });

  group('AreaBackgroundManager', () {
    test('starts with no image mappings', () {
      expect(manager.userImageMap, isEmpty);
      expect(manager.getImageForArea('Tantallon'), isNull);
    });

    test('setImageForArea adds mapping', () {
      manager.setImageForArea('Tantallon', '/images/town.png');
      expect(manager.getImageForArea('Tantallon'), '/images/town.png');
      expect(manager.userImageMap['Tantallon'], '/images/town.png');
    });

    test('removeImageForArea removes mapping', () {
      manager.setImageForArea('Tantallon', '/images/town.png');
      manager.removeImageForArea('Tantallon');
      expect(manager.getImageForArea('Tantallon'), isNull);
      expect(manager.userImageMap.containsKey('Tantallon'), false);
    });

    test('setImageForArea overwrites existing mapping', () {
      manager.setImageForArea('Tantallon', '/images/old.png');
      manager.setImageForArea('Tantallon', '/images/new.png');
      expect(manager.getImageForArea('Tantallon'), '/images/new.png');
    });

    test('loadUserImageMap replaces all mappings', () {
      manager.setImageForArea('Old', '/images/old.png');
      manager.loadUserImageMap({'New': '/images/new.png'});
      expect(manager.userImageMap.containsKey('Old'), false);
      expect(manager.getImageForArea('New'), '/images/new.png');
    });

    test('userImageMap returns unmodifiable copy', () {
      manager.setImageForArea('Tantallon', '/images/town.png');
      final map = manager.userImageMap;
      expect(() => (map as Map<String, String>)['x'] = 'y',
          throwsUnsupportedError);
    });

    test('getImageForArea returns null for unmapped area', () {
      manager.setImageForArea('Tantallon', '/images/town.png');
      expect(manager.getImageForArea('Wilderness'), isNull);
    });
  });
}
