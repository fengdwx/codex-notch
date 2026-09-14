#!/usr/bin/env python3
"""Check missing and wrong CI signing keys fail without producing a feed."""
import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
archive = Path(sys.argv[1]).resolve()
assert archive.is_file(), "Expected a real release archive"
with tempfile.TemporaryDirectory(prefix="codex-notch-signing-guard-") as temp:
    for label, key, expected in (
        ("missing", "", "SPARKLE_PRIVATE_KEY is required"),
        ("wrong", base64.b64encode(os.urandom(32)).decode(), "signature invalid"),
    ):
        feed = Path(temp) / f"{label}.xml"
        env = dict(os.environ, GITHUB_ACTIONS="true", SPARKLE_PRIVATE_KEY=key)
        result = subprocess.run(
            [str(root / "scripts/sign_update.sh"), str(archive), str(feed)],
            env=env, capture_output=True, text=True,
        )
        # Do not print captured signing output, even on failure.
        assert result.returncode != 0, f"{label} key unexpectedly succeeded"
        assert not feed.exists(), f"{label} key produced a feed"
        assert expected in result.stdout + result.stderr, f"{label} key failed for an unexpected reason"
        print(f"Verified {label} CI key is rejected without publishing a feed")
