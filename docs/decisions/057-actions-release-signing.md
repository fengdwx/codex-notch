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
