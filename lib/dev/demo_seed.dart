import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart'
    show commandHistoryProvider, inputControllerProvider, terminalBufferProvider;
import '../models/text_link_rule.dart';
import '../providers/game_state_provider.dart';
import '../providers/text_link_rule_provider.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/text_link_rules_screen.dart';
import '../ui/widgets/common/settings_drawer_route.dart';
import '../ui/widgets/mobile/target_picker_sheet.dart';
import '../ui/widgets/terminal/input_bar.dart' show showRecentCommandsSheet;

/// Compile-time flag that fills the client with a scripted session so App
/// Store screenshots can be captured without a live MUD connection.
///
///   flutter run -d macos --dart-define=AA_DEMO=terminal
///
/// Scenes:
///   - `terminal` → room output with kill links, text links, HUD + compass
///   - `kill`     → the same, with the Kill picker (Automatic Kill List) open
///   - `recent`   → the same, with Recent commands + Counterparts open
///   - `rules`    → the same, with the Text Link Rules pane open
///   - `hints`    → the same, with a half-typed command showing tap-able Hints
///
/// Empty (the default) leaves the app completely untouched.
const String kDemoScene = String.fromEnvironment('AA_DEMO', defaultValue: '');

bool get kIsDemoSeeded => kDemoScene.isNotEmpty;

/// A scripted arrival of MUD output. Written with real ANSI escapes so the
/// captured screenshots show the same colouring a player sees.
///
/// Chosen to exercise the kill-target linker honestly: `A giant eagle.` and
/// `A wild boar.` become red `kill` links on their head noun, while
/// `A shimmering blue door.` — same sentence shape, but scenery — stays plain.
const List<String> _transcript = [
  '\x1B[1;33mSnag creek bridge (n,e,w)\x1B[0m',
  '\x1B[37mThe planks creak underfoot. Below, the creek runs brown and fast\x1B[0m',
  '\x1B[37mafter the night\'s rain.\x1B[0m',
  '\x1B[36mA weathered signpost.\x1B[0m',
  '',
  '\x1B[37mYou go east.\x1B[0m',
  '',
  '\x1B[1;33mLight pine forest (n,e,s)\x1B[0m',
  '\x1B[37mTall pines crowd the trail, their needles muffling every step.\x1B[0m',
  '\x1B[37mA thin mist drifts between the trunks to the north.\x1B[0m',
  '\x1B[36mA shimmering blue door.\x1B[0m',
  '\x1B[32mA giant eagle.\x1B[0m',
  '\x1B[32mA wild boar.\x1B[0m',
  '',
  '\x1B[37mThe boar snorts and paws at the pine needles.\x1B[0m',
  '\x1B[33mThe eagle watches you with unblinking amber eyes.\x1B[0m',
  // Puts "goblin" into the recent-word corpus so the `hints` scene has a
  // real completion to offer for `kill gob`.
  '\x1B[37mA goblin scout darts between the trunks and is gone.\x1B[0m',
  '',
  '\x1B[31mYou must be standing.\x1B[0m',
];

/// Pre-filled input for the `hints` scene: a three-letter prefix that the
/// recent-word corpus completes to exactly one creature, so the chip reads
/// unambiguously as "tap to send `kill goblin`".
const String _hintsInput = 'kill gob';

/// Prompt lines fed to the game-state parser only — they drive the HUD and
/// the compass without appearing as terminal output, exactly as the real
/// client gags them.
const List<String> _promptLines = [
  '345/380:210/240>',
  // Snag creek country — fourteen gazetteer entries fall inside the
  // compass's 5-stadia range, so the rose fills with distinct names
  // (Giants' convention, Balan, Chaos tower, …) rather than repeats.
  'CLIENT:X:-7:Y:5:Chosen:mage:1837:245000',
];

/// Seeded so the Recent-commands sheet has a full list *and* several rows
/// with counterparts (enter→leave/out, open→close both ways). Oldest first.
const List<String> _commandHistory = [
  'score',
  'buy potion from shopkeeper',
  'wear leather armour',
  'wield staff',
  'get all from corpse',
  'cast fireball at eagle',
  'look in the pack',
  'read the notice board',
  'dotimes 30 north',
  'open north door',
  'enter portal',
];

/// A curated Text Link Rules list for the `rules` scene. Deliberately *not*
/// whatever is on the capturing machine's disk — that file holds the
/// developer's own play rules, which shouldn't ship in a store listing.
/// These read as an inviting tutorial: the two shipped defaults plus three
/// showing capture groups and multi-step follow-ups.
const List<TextLinkRule> _textLinkRules = [
  TextLinkRule(
    id: 'demo_stand',
    name: 'Stand up',
    pattern: r'You must be standing\.',
    commandTemplate: 'stand',
  ),
  TextLinkRule(
    id: 'demo_open_door',
    name: 'Open the closed door',
    pattern: r'The (\w+) door is closed\.',
    commandTemplate: r'open $1 door',
  ),
  TextLinkRule(
    id: 'demo_loot',
    name: 'Loot the kill',
    pattern: r'You killed',
    commandTemplate: 'get all from corpse',
  ),
  TextLinkRule(
    id: 'demo_accept',
    name: 'Accept',
    pattern: r"'accept'",
    commandTemplate: 'accept',
  ),
  TextLinkRule(
    id: 'demo_rest',
    name: 'Rest when weary',
    pattern: r'You are too tired to',
    commandTemplate: 'rest',
  ),
];

/// Fills every provider the screenshot scenes depend on. Idempotent enough
/// for a single post-frame call; never invoked outside `AA_DEMO` builds.
void seedDemoState(WidgetRef ref) {
  // Rules first: the transcript is linked against them as it is added.
  ref.read(textLinkRulesProvider.notifier).seedDemoRules(_textLinkRules);
  ref.read(terminalBufferProvider.notifier).seedDemoLines(_transcript);

  final gameState = ref.read(gameStateProvider.notifier);
  for (final line in _promptLines) {
    gameState.processLine(line);
  }

  // Replaces rather than appends: whatever this machine has in its real
  // Command History.md must not leak into a store screenshot.
  ref.read(commandHistoryProvider.notifier).seedDemoHistory(_commandHistory);
}

/// Wraps [HomeScreen] with the seeding + scene setup. Substituted for the
/// normal home in `AncientAnguishApp` when [kIsDemoSeeded].
class DemoHomeScreen extends ConsumerStatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  ConsumerState<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends ConsumerState<DemoHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      seedDemoState(ref);
      // Let the seeded output lay out (and the compass resolve its
      // neighbours) before putting a sheet or pane over the top of it.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await _openScene();
    });
  }

  Future<void> _openScene() async {
    switch (kDemoScene) {
      case 'kill':
        await TargetPickerSheet.show(context, commandLabel: 'Kill');
      case 'recent':
        await showRecentCommandsSheet(context, ref);
      case 'rules':
        await openSettingsDrawer(context, const TextLinkRulesScreen());
      case 'hints':
        // Typing into the shared controller is all the Hints bar needs —
        // it rebuilds off the controller, not off a focus or key event.
        ref.read(inputControllerProvider).text = _hintsInput;
      default:
        break; // 'terminal' — the seeded output is the shot.
    }
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
