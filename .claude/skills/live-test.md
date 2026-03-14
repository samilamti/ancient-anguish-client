---
name: live-test
description: Run integration tests against the live Ancient Anguish MUD server using the test account. Usage: /live-test [test-name]
---

# Live Server Test

Run integration tests against the live Ancient Anguish MUD server (ancient.anguish.org:2222).

## Test Account

- Username: `chosen`
- Password: `vinter`

## Important Notes

- Integration tests are in `test/integration/`
- These connect to a REAL server — don't run destructive commands
- If disconnected uncleanly, server asks "Throw the other copy out?" — send `yes`
- Guest login flow: "What is your name:" → `guest` → "Please enter your choice:" → `3`
- Can't use `dart run` for scripts that import Flutter — use `flutter test` instead
- Connection timeout to unreachable hosts is ~15s

## Steps

1. **Check connectivity**
   - Verify the server is reachable: test TCP connection to ancient.anguish.org:2222

2. **Identify test to run**
   - If user specified a test name, find matching file in `test/integration/`
   - If no test specified, list available integration tests and ask which to run
   - For running all: `flutter test test/integration/`

3. **Run the test**
   - Use `dart run test/integration/<test>.dart` for standalone Dart scripts
   - Use `flutter test test/integration/<test>.dart` for tests with Flutter dependencies
   - Watch for timeout — set a reasonable timeout (60s per test)

4. **Report results**
   - Show pass/fail status
   - If failures: show the relevant error output
   - If "Throw the other copy out?" appears: the previous session didn't disconnect cleanly

## Server Behavior Reference

- Prompt format: `prompt set |HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD| |SPACE|`
- SGA negotiated (no GA commands sent)
- Prompt arrives without newline — stays in buffer as pending data
- Server pads numbers with leading spaces + ANSI color codes
