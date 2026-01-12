#!/usr/bin/env python3
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
FIXTURES_DIR = BASE_DIR / "contracts" / "fixtures"


def main() -> None:
    path = FIXTURES_DIR / "lifecycle.ndjson"
    snapshot_hash = None
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        data = json.loads(line)
        payload = data.get("payload", {})
        current = payload.get("policy_snapshot_hash")
        if current is None:
            continue
        if snapshot_hash is None:
            snapshot_hash = current
        elif snapshot_hash != current:
            raise SystemExit(
                "Policy snapshot hash mismatch in lifecycle fixture. "
                f"Line {line_number} has {current}, expected {snapshot_hash}."
            )

    print("Snapshot hashes are consistent across lifecycle fixture.")


if __name__ == "__main__":
    main()
