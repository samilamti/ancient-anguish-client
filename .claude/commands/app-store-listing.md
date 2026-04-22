---
description: Draft App Store Listings vX.Y.Z.md for the current pubspec version, reusing the latest listing as a template.
---

# /app-store-listing

Draft (or update) the per-version store listing document for the current version.

## Steps

1. **Read the version** from `pubspec.yaml` (the `version:` line — take the X.Y.Z part before the `+build`).

2. **Find the previous listing** — glob `App Store Listings v*.md`, pick the highest version (by semver). That's the template.

3. **Check for an existing listing** at `App Store Listings v<version>.md`. If it exists, offer to update it rather than starting fresh; diff only the sections that change per release (What's New, Reviewer Notes, Screenshot shot list, "supersedes" link).

4. **Gather the "what's new" material**:
   - Read `Version History/v<version>.md` if it exists.
   - If it doesn't exist, fall back to `git log <previous-tag>..HEAD --oneline` where previous-tag comes from `git tag --sort=-v:refname | head -1`.
   - Summarize the user-visible changes only (skip refactors, test-only commits, CI tweaks) in plain language. No marketing puffery, no emoji. Follow the tone in `App Store Listings v6.8.0.md` — honest, understated, direct.

5. **Draft the new listing** by copying the previous listing wholesale, then:
   - Update the top paragraph and the "supersedes" sentence.
   - Rewrite each "What's New in v<version>" block for iOS, macOS, and Android (respecting the ≤4000-char limit noted per section).
   - Only rewrite the Reviewer Notes addendum if App Review will see something new this release (new IAP, new entitlement, new capability). If the release is purely bug fixes or UI polish, say so in one line and note that the v6.8.0 reviewer notes still apply.
   - Update the Screenshot shot list if new screens were added. Reference `scripts/app-store-screenshots.sh` for batch capture.
   - If IAPs or subscription products changed, update Section 4 accordingly; otherwise keep it unchanged.
   - Bump the Verification checklist to reflect what this release actually needs.

6. **Do NOT invent facts**. If you're unsure whether a change is user-visible (e.g. a refactor), ask Sami. If a section in the previous listing references "design task out of scope" items (e.g. 1024×1024 promo PNGs), carry the TODO forward unchanged.

7. **Respect Sami's naming rule**: on pages hosted at anguish.org the product name is not repeated. For the App Store copy itself the full name is fine.

8. **Write** the result to `App Store Listings v<version>.md` at the repo root.

9. **Report** the diff vs. the previous listing (file size delta + sections changed) so Sami can skim what to review.

## Notes

- Character counts matter — the previous listing annotates them per field. Keep them.
- iOS "Promotional Text" (170) and "Subtitle" (30) are the easiest to overflow; double-check these in particular.
- Don't commit the file automatically — leave that to Sami or to the `app-store-submission` skill.
