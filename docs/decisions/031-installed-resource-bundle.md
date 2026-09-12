---
status: active
contract_ids: [PACKAGE-VERIFY-006, NOTCH-VISIBILITY-048]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-07
last_verified_commit: null
---

# Resolve animation resources inside the installed application

The v0.1.14 app crashed in SwiftPM's generated Bundle.module accessor before
showing the floating bar. Packaging correctly put resources in Contents/Resources,
but the accessor searched the .app root and the builder's absolute .build path.
Directly starting the downloaded binary reproduced the fatal error.

For .app launches, resolve only the resource bundle under Bundle.main.resourceURL.
If missing, return nil so optional images do not crash the app. Use Bundle.module
only for standalone SwiftPM builds and tests. Never evaluate that generated
accessor as an installed-app fallback. Keep resources inside the signed bundle;
placing a copy at its root was rejected because strict signing reports unsealed
contents. Do not depend on another user's build tree or change authentication.

The verification CLI switch decodes the atlas and three PNG images, exits before
credentials/session startup, and fails when any are missing. Full bundle
verification runs this switch. A relocated-app fixture verifies bundled lookup
and missing-resource behavior even while local SwiftPM resources exist.
