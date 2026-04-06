---
name: new-feature
description: Scaffold a new feature with model, service, provider, and test following project conventions. Usage: /new-feature <feature-name>
---

# New Feature Scaffold

Create the standard file set for a new feature following this project's established architecture.

The user will provide a feature name (e.g., "macro", "timer", "map"). Use it to derive file and class names.

## Steps

1. Ask the user for:
   - Feature name (if not provided in the command)
   - Brief description of what the feature does
   - Whether it manages a list of rules/items (like triggers/aliases) or a single state (like game state)

2. Create model in `lib/models/<feature>.dart` or `lib/models/<feature>_rule.dart`
3. Create service in `lib/services/<feature>/<feature>_engine.dart` or `lib/services/<feature>/<feature>_service.dart`
4. Create provider in `lib/providers/<feature>_provider.dart`
5. Create test in `test/services/<feature>_engine_test.dart`
6. Run `bash scripts/validate.sh` to verify

## Reference Patterns

Use these files as templates — read them before generating code:

- **Model**: `lib/models/trigger_rule.dart`
- **Service**: `lib/services/trigger/trigger_engine.dart`
- **Provider**: `lib/providers/trigger_provider.dart`
- **Test**: `test/services/trigger_engine_test.dart`

## Conventions

### Model
- Plain Dart class, no code generation annotations
- All fields `final`
- Constructor with named parameters and sensible defaults
- `copyWith()` method: use `??` for non-nullable fields. For nullable fields that need to be explicitly set to null, use the sentinel pattern (`_Absent` class) from `lib/providers/audio_provider.dart`
- `toJson()` and `fromJson()` factory if persisted
- `toString()` override
- Unique `id` field (String) if part of a collection

### Service
- Pure Dart class (avoid Flutter imports)
- Constructor takes dependencies as parameters, not from Riverpod
- CRUD methods: add, remove, update, get, setAll/setRules
- `List.unmodifiable()` for collection getters
- Callback fields for side-effect notifications (e.g., `onTriggerFired`)

### Provider
- Service provider: `final <feature>EngineProvider = Provider<FeatureEngine>((ref) => FeatureEngine())`
- State provider: `final <feature>RulesProvider = NotifierProvider<FeatureRulesNotifier, List<FeatureRule>>(FeatureRulesNotifier.new)`
- Notifier extends `Notifier<T>`:
  - `build()` reads engine via `ref.read(engineProvider)`, loads defaults
  - CRUD methods delegate to engine, then `state = List.unmodifiable(engine.rules)`
  - **All fire-and-forget async methods MUST have internal try-catch** (critical project rule)
  - `ref.read()` for one-time access, `ref.watch()` for reactive, `ref.listen()` for side effects

### Riverpod 3.1.0 specifics
- `AsyncValue.value` returns nullable `T?` on `AsyncLoading` — use `?? defaultValue`
- `NotifierProvider` uses `.new` constructor reference
- No code generation — hand-written providers only

### Test
- Import from `package:ancient_anguish_client/...` (not relative)
- `flutter_test` package
- `setUp()` creates fresh instance
- Group tests: "Rule management", "Processing", "Edge cases"
- Test CRUD, core logic, `copyWith()`, `toJson()`/`fromJson()` round-trip
