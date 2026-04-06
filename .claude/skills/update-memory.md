---
name: update-memory
description: Review recent changes and update Claude memory files to keep project knowledge current. Usage: /update-memory
---

# Update Memory

Review recent development activity and update the Claude memory files to reflect the current state of the project.

## Memory Location

`C:\Users\samil\.claude\projects\S--Ancient-Anguish-Client\memory\`

Files:
- `MEMORY.md` — main project memory (index + inline knowledge)
- `architecture.md` — file map, providers, data flow
- `audio-system.md` — audio architecture and patterns
- `testing.md` — test patterns and coverage

## Steps

1. **Assess recent changes**
   - Run `git log --oneline -20` to see recent commits
   - Run `git diff HEAD~10..HEAD --stat` to see files changed (adjust range as needed)
   - Identify new features, architecture changes, or pattern shifts

2. **Read current memory files**
   - Read all four memory files
   - Note any stale or incorrect information

3. **Cross-reference**
   - Compare memory claims against actual code:
     - Test count in `testing.md` vs `flutter test` output
     - Provider table in `architecture.md` vs actual providers in `lib/providers/`
     - Audio patterns in `audio-system.md` vs actual `audio_service.dart`
   - Check if new providers, services, or features are missing from memory

4. **Update memory files**
   - Fix stale information (wrong counts, outdated patterns)
   - Add new features and systems
   - Update architecture if data flow changed
   - Keep entries concise — memory is for non-obvious knowledge, not code documentation

5. **Verify MEMORY.md index**
   - Ensure all memory files are linked from `MEMORY.md`
   - Keep index under 200 lines (truncated beyond that)

## What NOT to Put in Memory

- Code patterns derivable from reading the code
- Git history (use `git log`)
- Things already in CLAUDE.md
- Temporary/in-progress work
- Debugging solutions (the fix is in the code)

## What TO Update

- Test counts and known failures
- New provider/service additions to architecture table
- New design patterns (e.g., queue-latest, sentinel copyWith)
- System behavior quirks (server protocol, Flutter version gotchas)
- Feature descriptions that affect how Claude should work with the code
