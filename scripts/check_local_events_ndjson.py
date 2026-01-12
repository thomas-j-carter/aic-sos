#!/usr/bin/env python3
import json
from pathlib import Path

try:
    from jsonschema import Draft7Validator
except ImportError as exc:
    raise SystemExit("jsonschema is required. Install with: pip install jsonschema") from exc

BASE_DIR = Path(__file__).resolve().parents[1]
CONTRACTS_DIR = BASE_DIR / "contracts"
EVENTS_PATH = BASE_DIR / ".astraai" / "local" / "events.ndjson"

EVENT_SCHEMAS = {
    "run.created": CONTRACTS_DIR / "events" / "run.created.schema.json",
    "run.policy.requested": CONTRACTS_DIR / "events" / "run.policy.requested.schema.json",
    "run.policy.decided": CONTRACTS_DIR / "events" / "run.policy.decided.schema.json",
    "run.paused.awaiting_approval": CONTRACTS_DIR / "events" / "run.paused.awaiting_approval.schema.json",
    "run.approved": CONTRACTS_DIR / "events" / "run.approved.schema.json",
    "run.started": CONTRACTS_DIR / "events" / "run.started.schema.json",
    "run.completed": CONTRACTS_DIR / "events" / "run.completed.schema.json",
    "run.failed": CONTRACTS_DIR / "events" / "run.failed.schema.json",
    "run.blocked": CONTRACTS_DIR / "events" / "run.blocked.schema.json",
}


def load_schema(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_json(data: dict, schema: dict, label: str) -> None:
    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda err: err.path)
    if errors:
        message = "\n".join(f"{label}: {error.message}" for error in errors)
        raise SystemExit(message)


def main() -> None:
    if not EVENTS_PATH.exists():
        print("No local events.ndjson found. Skipping validation.")
        return

    schema_cache = {event: load_schema(path) for event, path in EVENT_SCHEMAS.items()}
    for line_number, line in enumerate(EVENTS_PATH.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_type = data.get("event_type")
        if event_type not in schema_cache:
            raise SystemExit(f"Unknown event_type {event_type} on line {line_number}")
        validate_json(data, schema_cache[event_type], f"events.ndjson:{line_number}")

    print("Local events.ndjson validated successfully.")


if __name__ == "__main__":
    main()
