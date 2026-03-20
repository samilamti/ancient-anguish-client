---
name: release
description: Full release workflow — update memory, create logical commits, write release notes, push, and tag. Usage: /release [version]
---

# Release

Orchestrate a complete release: update project memory, commit all changes logically, write release notes, push to origin, and create an immutable version tag.

## Prerequisites

- Must be on the `main` branch
- Must have network access to push to `origin`
- Working tree may have uncommitted changes (they will be committed during the process)

## Phase 1: Gather Info

1. **Ask for version number** if not provided as an argument
   - Must start with `v` (e.g., `v5.4`)
   - Verify the tag does not already exist: `git tag -l <version>`
   - If it exists, stop — tags are immutable on this repo

2. **Determine previous release**
   - Run `git tag --sort=-v:refname | head -1` to get the latest existing tag
   - This becomes the "Previous release" in the release notes

3. **Verify branch**
   - Run `git branch --show-current` — must be `main`
   - If not on main, warn the user and stop

## Phase 2: Update Memory

Review recent changes and update the Claude memory files so that memory commits are included in this release.

**Memory location:** `C:\Users\samil\.claude\projects\S--Ancient-Anguish-Client\memory\`

Files: `MEMORY.md`, `architecture.md`, `audio-system.md`, `testing.md`

1. **Assess recent changes**
   - Run `git log --oneline -20` to see recent commits
   - Run `git diff HEAD~10..HEAD --stat` to see files changed
   - Identify new features, architecture changes, or pattern shifts

2. **Read current memory files**
   - Read all four memory files
   - Note any stale or incorrect information

3. **Cross-reference**
   - Compare memory claims against actual code:
     - Test count in `testing.md` vs `flutter test` output
     - Provider table in `architecture.md` vs actual providers in `lib/providers/`
     - Audio patterns in `audio-system.md` vs actual audio service
   - Check if new providers, services, or features are missing from memory

4. **Update memory files**
   - Fix stale information (wrong counts, outdated patterns)
   - Add new features and systems
   - Update architecture if data flow changed
   - Keep entries concise — memory is for non-obvious knowledge, not code documentation

5. **Do NOT commit memory changes yet** — they will be grouped in Phase 3

## Phase 3: Create Logical Commits

Group all uncommitted changes (including memory updates from Phase 2) into well-organized commits.

1. **Audit working tree**
   - Run `git status` and `git diff --stat` to see all changes
   - Run `git diff` for each modified file to understand what changed
   - Check for new untracked files and read them

2. **Security check**
   - Flag any sensitive files (keys, passwords, `.env`, credentials)
   - NEVER commit sensitive files

3. **Group changes logically**
   - Identify distinct features, bug fixes, or refactors
   - Group files that belong to the same logical change
   - Order commits so dependencies come first
   - Memory file updates should be their own commit (e.g., "Update project memory for vX.Y")

4. **Create commits**
   - For each group: `git add <specific files>` then `git commit`
   - Commit message format: imperative summary line, blank line, brief explanation of *why*
   - Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` in every commit
   - Follow project style: imperative present tense, under 72 chars, no conventional commit prefixes

5. **Verify**
   - Run `git log --oneline` to show the new commits
   - Run `git status` to confirm working tree is clean

## Phase 4: Write Release Notes

Create the release notes file BEFORE tagging (required by project convention).

1. **Analyze changes since last tag**
   - Run `git log <previous-tag>..HEAD --oneline` to see all commits in this release
   - Run `git diff <previous-tag>..HEAD --stat` to see all files changed

2. **Get test counts**
   - Run `flutter test` and note the passing count
   - Run `cd server && dart test` for server test count
   - Run `flutter analyze --fatal-infos` — note 0 analysis errors

3. **Create `Version History/vX.Y.md`** following this format:

   ```
   # vX.Y Release Notes

   **Date:** <Month DD, YYYY>
   **Previous release:** <prev tag> (<Month DD, YYYY>)

   ---

   ## Highlights

   One-two sentence summary of the most notable changes.

   ---

   ## Improvements

   ### Feature Name
   - Details about the improvement

   ## Bug Fixes
   - Description of fix (only include if there are bug fixes)

   ---

   ## Technical Details

   - Key files changed
   - XXX client tests passing, XX server tests passing, 0 analysis errors
   ```

4. **Commit the release notes**
   - `git add "Version History/vX.Y.md"`
   - Commit message: `Add vX.Y release notes`
   - Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## Phase 5: Push Commits

**CONFIRMATION GATE — ask user before proceeding.**

Show the user:
- Number of new commits since the previous tag
- Run `git log <previous-tag>..HEAD --oneline` and display it
- Ask: "Ready to push these commits to origin/main?"

Only after user confirms:
1. Run `git push origin main`
2. Verify push succeeded
3. If push fails, stop and report the error

## Phase 6: Tag and Push Tag

**CONFIRMATION GATE — ask user before proceeding.**

Show the user:
- The version tag to be created
- Remind them: "Tags are immutable on this repo — this cannot be undone"
- Ask: "Ready to run validation, create tag, and push?"

Only after user confirms:

1. **Run validation**
   - `flutter analyze --fatal-infos` — if fails, stop and report
   - `flutter test` — if fails, stop and report

2. **Create and push tag**
   - `git tag <version>`
   - `git push origin <version>`

3. **Report success**
   - "Release <version> tagged and pushed. GitHub Actions will build release artifacts automatically."
   - Derive repo URL from `git remote get-url origin` and link to Actions page

## Error Recovery

- **Validation fails in Phase 6**: Fix the issue, commit the fix, restart from Phase 5
- **Push fails**: Check network/permissions, retry
- **Tag already exists**: Cannot re-tag — user must choose a new version number
- **Wrong branch**: Switch to main first, or abort
