---
description: Query App Store Connect for recent build processing / TestFlight state. Usage: /testflight-status [version]
---

# /testflight-status

Report the processing + TestFlight state of recent App Store Connect builds so Sami doesn't have to open the ASC dashboard.

## Steps

1. **Parse argument** — if the user passes a version (e.g. `6.10.0`), scope to builds for that pre-release version. Otherwise show the most recent 10 builds across all versions.

2. **Run the helper script:**

   ```bash
   ruby scripts/testflight-status.rb ${version:+--version "$version"}
   ```

   The script:
   - Auto-discovers the `.p8` key in `AppStore Connect Stuff for Ancient Anguish Client/AuthKey_*.p8`
   - Extracts the key ID from the filename
   - Reads `ASC_ISSUER_ID` from env or from `.asc/issuer_id`
   - Signs a short-lived ES256 JWT and queries the ASC API

3. **If the script aborts with "ASC_ISSUER_ID is not set"**, tell Sami to:
   - Grab the issuer UUID from https://appstoreconnect.apple.com/access/api (top of the Keys tab)
   - Save it with:
     ```
     mkdir -p .asc && echo '<uuid>' > .asc/issuer_id && grep -q '^\.asc/' .gitignore || echo '.asc/' >> .gitignore
     ```

4. **If the script aborts with a 401 / NOT_AUTHORIZED**, the issuer ID or the `.p8` key is wrong. Verify the key ID (filename) matches an active key on ASC and that the issuer ID is for the same team.

5. **Interpret the output for Sami** in plain English:
   - Pick out the newest build for each version
   - Flag anything `PROCESSING` (CI is still transcoding), `FAILED`, `INVALID`, or `REJECTED`
   - If a build is `IN_BETA_TESTING` with `externalBuildState == READY_FOR_BETA_TESTING` and Sami tagged recently, note that testers can now install it
   - If a build is older than 90 days and marked `expired`, mention it

6. **If Sami just tagged a release** (the most recent tag is newer than the newest build's uploadedDate), note that CI may still be building — suggest running `bash scripts/ci-status.sh --watch` first.

## Notes

- The script never writes anywhere. It only GETs from api.appstoreconnect.apple.com.
- `.asc/issuer_id` and the `.p8` key must NEVER be committed — confirm `.gitignore` covers both.
- Pass `--json` to the script if Sami wants raw output for piping.
