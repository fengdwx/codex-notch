# Publisher update workflow

CodexNotch uses Sparkle 2.9.6 with an Ed25519 update key. The private key stays in
the publisher's login Keychain, under account `com.david.codexnotch.sparkle` and
service `https://sparkle-project.org`. Only the public key is in `Resources/Info.plist`.
Users do not generate or download keys.

## Publish a version

1. Increase both `CFBundleShortVersionString` and `CFBundleVersion`; write
   user-facing notes in `docs/releases/<version>.md`.
2. Run `./scripts/verify.sh`, then `RUN_TESTS=0 ./scripts/release.sh` on the
   publisher's Mac. Sparkle's `generate_appcast` may ask for Keychain permission
   on its first use. No private key is exported. The release script independently
   verifies the generated signature against the app's public key.
3. When a release is authorized, upload the generated ZIP, DMG and checksums to
   the matching `v<version>` GitHub Release. Read back the public archive URLs.
4. Copy `dist/appcast.xml` over the tracked `appcast.xml`, commit it and push it
   to personal `main` only after the archive is publicly available.
5. Check for Updates from an older updater-enabled installation; verify the
   offered version, download, installation, relaunch, and saved preferences.

The tracked feed initially contains no items. Merely building a release does
not advertise unpublished files or overwrite the production feed. Do not edit
archive bytes after signing. The feed currently advertises full ZIP updates;
it does not generate deltas or beta channels.

## Local contributors and key storage

`swift test`, `build_app.sh`, and `verify.sh` do not need the private key. Only
publisher release signing requires it. Forks need their own key, feed URL, and
release destination; never share the publisher's key with application users.
Keep the existing Keychain when moving the release workflow to another Mac.
Key migration, backups, or CI storage are separate explicit operations; this
setup does not export the key, add GitHub secrets, or obtain Apple certificates.

Apple Developer ID signing/notarization is separate. The app still uses an
ad-hoc signature; updating does not promise to eliminate Gatekeeper prompts.
Restore the saved previous app if a local test fails. Withdraw a faulty public
feed entry and publish a higher corrective build for users already updated.
