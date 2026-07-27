import 'package:ancient_anguish_client/models/alias_rule.dart';
import 'package:ancient_anguish_client/providers/alias_provider.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/link_command_provider.dart';
import 'package:ancient_anguish_client/services/alias/alias_engine.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a tapped link would put on the wire.
class _FakeConnectionService extends TcpConnectionService {
  final List<String> sent = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) => sent.add(command);
}

void main() {
  late _FakeConnectionService service;
  late ProviderContainer container;

  /// A container whose alias engine holds [rules] (or the shipped defaults,
  /// which include `k` → `kill $1`).
  ProviderContainer containerWith([List<AliasRule>? rules]) {
    service = _FakeConnectionService();
    final engine = AliasEngine()..setRules(rules ?? AliasEngine.defaultAliases());
    final c = ProviderContainer(overrides: [
      connectionServiceProvider.overrideWithValue(service),
      aliasEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  void tap(String command) => container.read(linkCommandSenderProvider)(command);

  group('link commands run through the alias engine', () {
    test("Sami's report: a link emitting `k hare` fires the `k` alias", () {
      container = containerWith();
      tap('k hare');
      expect(service.sent, ['kill hare']);
    });

    test('an alias chain sends every command it expands to', () {
      container = containerWith([
        const AliasRule(
          id: 'a1',
          keyword: 'k',
          expansion: r'wield sword;kill $1',
        ),
      ]);
      tap('k troll');
      expect(service.sent, ['wield sword', 'kill troll']);
    });

    test('a command with no matching alias goes out verbatim', () {
      container = containerWith();
      tap('kill hare');
      expect(service.sent, ['kill hare']);
    });

    test('a disabled alias does not fire', () {
      container = containerWith([
        const AliasRule(
          id: 'a1',
          keyword: 'k',
          expansion: r'kill $1',
          enabled: false,
        ),
      ]);
      tap('k hare');
      expect(service.sent, ['k hare']);
    });

    test('a blank command is a silent no-op', () {
      container = containerWith();
      tap('   ');
      expect(service.sent, isEmpty);
    });

    test('the alias keyword must be a whole word', () {
      // `kill` starts with `k` but is not the alias — an unguarded
      // startsWith would send `kill ill hare`.
      container = containerWith();
      tap('killer hare');
      expect(service.sent, ['killer hare']);
    });
  });
}
