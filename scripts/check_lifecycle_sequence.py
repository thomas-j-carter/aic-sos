#!/usr/bin/env python3
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
FIXTURES_DIR = BASE_DIR / "contracts" / "fixtures"

EXPECTED_SEQUENCE = [
    "run.created",
    "run.policy.requested",
    "run.policy.decided",
    "run.paused.awaiting_approval",
    "run.approved",
    "run.started",
    "run.completed",
]


def main() -> None:
    path = FIXTURES_DIR / "lifecycle.ndjson"
    events = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            events.append(json.loads(line)["event_type"])

    if events != EXPECTED_SEQUENCE:
        raise SystemExit(
            "Lifecycle event sequence mismatch.\n"
            f"Expected: {EXPECTED_SEQUENCE}\n"
            f"Found:    {events}"
        )

    print("Lifecycle sequence matches expected order.")


if __name__ == "__main__":
    main()
