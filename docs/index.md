---
layout: default
title: Privacy Policy
description: Privacy policy for the Ancient Anguish Client — an independent, third-party MUD client.
---

# Ancient Anguish Client — Privacy Policy

**Last updated:** April 18, 2026

Ancient Anguish Client is an independent third-party client for [Ancient Anguish](https://anguish.org/), a text-based multiplayer fantasy game that has been running since 1991. This policy explains, plainly, what data the client does and does not handle.

## The short version

- No analytics.
- No tracking.
- No advertising.
- No third-party SDKs (no Firebase, Sentry, Mixpanel, Crashlytics, or similar).
- No account is required with the client itself.
- Your data stays on your device.

If you want the longer version, read on.

## What stays on your device

All of the following are stored locally on your device using the Hive local-storage library, and nothing in this list leaves your device:

- Character credentials (the username and password you use to log in to the MUD).
- Connection settings (host, port, auto-reconnect preferences).
- Aliases, Immersions (triggers), and HUD preferences.
- Theme choices and custom color palettes.
- Scrollback buffer and session logs.
- Quick Command definitions.

If you uninstall the app, all of this data is removed with it.

## Network traffic

The client opens a **single outbound TCP socket** to the MUD server you tell it to connect to. By default, that is `ancient.anguish.org:2222`. You can change the host and port at any time in the app's settings.

- On the iOS, Android, macOS, Windows, and Linux builds, this connection is a direct TCP socket.
- On the web build (if you use it), the same traffic is tunneled through a WebSocket-to-TCP proxy hosted under the AA domain. This is a transport detail only and does not change what information is sent.

No other network connections are made by the client. No content is uploaded to any other service.

## Permissions

- **iOS.** The app's Info.plist includes purpose strings for camera, microphone, and photo library. These exist solely because Flutter's `file_picker` plugin links those symbols at the framework level. The client itself never invokes camera, microphone, or photo-library APIs. You will never see a permission prompt for them from this app.
- **Android.** The app requests only the `INTERNET` permission, which is required to connect to the MUD server.
- **macOS.** The app is sandboxed with the standard outgoing-network entitlement and no additional privileges.

## In-game data

Anything you type, say, or do inside Ancient Anguish travels to the MUD server and is subject to the game's own rules and records. Ancient Anguish is an independent service operated by its own team. For questions about what the game itself records or retains, contact Ancient Anguish directly at [https://anguish.org/](https://anguish.org/).

## Children

The client does not knowingly collect data from anyone, and the game's in-world content includes fantasy violence and unmoderated player chat. We rate the app **12+ (Apple) / Teen (Google Play)**. Parental discretion is advised.

## Changes

If this policy changes, the updated version will be published in the app's **About** screen and at [https://anguish.org/connect.php](https://anguish.org/connect.php).

## Contact

Questions or concerns? Visit [https://anguish.org/](https://anguish.org/) and use the contact links there.
