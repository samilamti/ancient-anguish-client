import 'package:test/test.dart';

import 'package:ancient_anguish_server/src/files/file_whitelist.dart';

void main() {
  group('FileWhitelist', () {
    group('allowed names', () {
      test('accepts Immersions.md', () {
        expect(FileWhitelist.validate('Immersions.md'), 'Immersions.md');
      });

      test('accepts Aliases.md', () {
        expect(FileWhitelist.validate('Aliases.md'), 'Aliases.md');
      });

      test('accepts Area Configuration.md', () {
        expect(FileWhitelist.validate('Area Configuration.md'),
            'Area Configuration.md');
      });

      test('accepts alts.json', () {
        expect(FileWhitelist.validate('alts.json'), 'alts.json');
      });

      test('rejects old Chat History.md (now subfolder)', () {
        expect(FileWhitelist.validate('Chat History.md'), isNull);
      });

      test('rejects old Tell History.md (now subfolder)', () {
        expect(FileWhitelist.validate('Tell History.md'), isNull);
      });

      test('accepts Command History.md', () {
        expect(FileWhitelist.validate('Command History.md'),
            'Command History.md');
      });

      test('accepts settings.json', () {
        expect(FileWhitelist.validate('settings.json'), 'settings.json');
      });
    });

    group('chat history subfolder', () {
      test('accepts valid chat history date file', () {
        expect(FileWhitelist.validate('Chat History/2026-03-17.md'),
            'Chat History/2026-03-17.md');
      });

      test('rejects chat history with bad date', () {
        expect(FileWhitelist.validate('Chat History/not-a-date.md'), isNull);
      });

      test('rejects chat history with path traversal', () {
        expect(FileWhitelist.validate('Chat History/../evil.md'), isNull);
      });
    });

    group('tell history subfolder', () {
      test('accepts valid tell history date file', () {
        expect(FileWhitelist.validate('Tell History/2026-03-17.md'),
            'Tell History/2026-03-17.md');
      });

      test('rejects tell history with bad date', () {
        expect(FileWhitelist.validate('Tell History/not-a-date.md'), isNull);
      });
    });

    group('log files', () {
      test('accepts valid log file name', () {
        expect(FileWhitelist.validate('logs/session_2026-03-15T10-00-00.txt'),
            'logs/session_2026-03-15T10-00-00.txt');
      });

      test('rejects log with path traversal', () {
        expect(FileWhitelist.validate('logs/../etc/passwd'), isNull);
      });

      test('rejects log with wrong prefix', () {
        expect(FileWhitelist.validate('logs/notasession.txt'), isNull);
      });
    });

    group('path traversal', () {
      test('rejects ..', () {
        expect(FileWhitelist.validate('../etc/passwd'), isNull);
      });

      test('rejects embedded ..', () {
        expect(FileWhitelist.validate('foo/../bar'), isNull);
      });

      test('rejects backslash', () {
        expect(FileWhitelist.validate('foo\\bar'), isNull);
      });

      test('rejects absolute path', () {
        expect(FileWhitelist.validate('/etc/passwd'), isNull);
      });

      test('rejects null byte', () {
        expect(FileWhitelist.validate('alts.json\x00.txt'), isNull);
      });

      test('rejects empty string', () {
        expect(FileWhitelist.validate(''), isNull);
      });
    });

    group('unknown names', () {
      test('rejects random file name', () {
        expect(FileWhitelist.validate('hacker.txt'), isNull);
      });

      test('rejects similar but wrong name', () {
        expect(FileWhitelist.validate('immersions.md'), isNull); // Case matters.
      });
    });
  });
}
