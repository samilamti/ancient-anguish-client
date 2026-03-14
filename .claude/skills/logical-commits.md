---
name: logical-commits
description: Review uncommitted changes and create a series of logical, well-grouped git commits. Usage: /logical-commits
---

# Logical Commits

Review all uncommitted changes in the working tree and create a series of well-organized commits, each covering a single logical change.

## Steps

1. **Audit working tree**
   - Run `git status` and `git diff --stat` to see all changes
   - Run `git diff` for each modified file to understand what changed
   - Check for new untracked files and read them

2. **Security check**
   - Flag any sensitive files (keys, passwords, `.env`, credentials)
   - Verify `.gitignore` covers them — update if needed
   - NEVER commit sensitive files

3. **Group changes logically**
   - Identify distinct features, bug fixes, or refactors
   - Group files that belong to the same logical change
   - Order commits so dependencies come first (e.g., constants before the code that uses them)

4. **Create commits**
   - For each group: `git add <specific files>` then `git commit`
   - Commit message format: imperative summary line, blank line, brief explanation of *why*
   - Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

5. **Verify**
   - Run `git log --oneline` to show the new commits
   - Run `git status` to confirm working tree is clean (except intentionally untracked files)

## Commit Message Style

Follow the project's existing style (see `git log --oneline -10`):
- Imperative present tense ("Add", "Fix", "Remove", not "Added", "Fixed")
- Short summary (under 72 chars)
- Body explains motivation, not mechanics
- No conventional commit prefixes (no `feat:`, `fix:`, etc.)

## Grouping Heuristics

- Same feature across model/service/provider/test = one commit
- Config/constants changes go with the code that uses them
- Test-only changes can be separate if they don't accompany a feature
- `.gitignore` / build config changes = their own commit
- Emoji/cosmetic changes = their own commit
