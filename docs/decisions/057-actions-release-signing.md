---
status: active
contract_ids: [RELEASE-SIGNING-001, APP-UPDATE-002, CI-VERIFICATION-001]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-14
last_verified_commit: null
---

# Package signed releases on GitHub Actions

The maintainer explicitly authorized uploading the existing Sparkle private key
and enabling cloud packaging. This extends ADR 047's local-only key storage
choice; updater behavior and the public key remain unchanged.

Use a manual main-only workflow with read-only repository permissions. Run full
verification before packaging, expose SPARKLE_PRIVATE_KEY only to the packaging
step, and stream it to generate_appcast through stdin. Do not export key files,
import the key into the runner Keychain, or pass secret values as arguments.
Missing CI secrets fail without falling back to Keychain. Local signing retains
the original Keychain fallback. verify_update.swift independently checks the
archive against the embedded public key before artifacts are uploaded.

Upload only ZIP, DMG, checksums, appcast and source SHA. Publication remains a
separate maintainer operation after local verification and CI for the exact
source pass. Verify public assets before pushing the appcast. This avoids
publishing every manual package run or giving the packaging job write access.

L3 acceptance: local full verification, real successful hosted packaging using
the Secret, public-key verification of downloaded artifacts, and missing/wrong
key rejection. Rollback: disable the package workflow or delete the Actions
Secret; the existing local Keychain and existing public updates remain usable.
This does not change Apple signing or notarization and does not assert fresh
physical-device or in-app installation acceptance.

References: [Sparkle CI signing](https://github.com/sparkle-project/Sparkle/discussions/2308),
[GitHub artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data).

## Verified release, 2026-09-14

- Release source: `be16b6f0af5f76066475c529b69ffc62fc57df2d`.
- Local full verification: 236 tests, two existing opt-in skips, zero failures;
  bundle, resources and code signatures passed.
- [CI](https://github.com/fengdwx/codex-notch/actions/runs/34834445819) and
  [hosted packaging](https://github.com/fengdwx/codex-notch/actions/runs/34834447664)
  passed for that exact source. Hosted packaging also rejected missing/wrong keys.
- Downloaded cloud ZIP passed independent Ed25519 verification with the app's
  existing public key; both archives matched their SHA-256 checksum files.
- Release v0.2.3 uses these cloud-built assets. No publisher key file was created.
- Earlier CI failures exposed delayed file events bypassing bounded history
  discovery. A deterministic failing regression reproduced eight reads instead
  of five; the source fix passed both final CI runs without weakening assertions.
- Fresh end-to-end in-app installation and physical-notch appearance were not
  re-tested in this release operation.
