#!/usr/bin/env python3
import json
import sys
from pathlib import Path

try:
    from jsonschema import Draft7Validator
except ImportError as exc:
    raise SystemExit("jsonschema is required. Install with: pip install jsonschema") from exc


BASE_DIR = Path(__file__).resolve().parents[1]
CONTRACTS_DIR = BASE_DIR / "contracts"
FIXTURES_DIR = CONTRACTS_DIR / "fixtures"


CORE_API_SCHEMAS = {
    "evaluate_policy.request.json": CONTRACTS_DIR / "core_api" / "evaluate_policy.request.schema.json",
    "evaluate_policy.response.json": CONTRACTS_DIR / "core_api" / "evaluate_policy.response.schema.json",
    "issue_approval_token.request.json": CONTRACTS_DIR / "core_api" / "issue_approval_token.request.schema.json",
    "issue_approval_token.response.json": CONTRACTS_DIR / "core_api" / "issue_approval_token.response.schema.json",
    "execute_run.request.json": CONTRACTS_DIR / "core_api" / "execute_run.request.schema.json",
    "execute_run.response.json": CONTRACTS_DIR / "core_api" / "execute_run.response.schema.json",
}

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


def validate_core_fixtures() -> None:
    for fixture_name, schema_path in CORE_API_SCHEMAS.items():
        fixture_path = FIXTURES_DIR / fixture_name
        data = json.loads(fixture_path.read_text(encoding="utf-8"))
        schema = load_schema(schema_path)
        validate_json(data, schema, fixture_name)


def validate_event_fixtures() -> None:
    ndjson_path = FIXTURES_DIR / "lifecycle.ndjson"
    schema_cache = {event: load_schema(path) for event, path in EVENT_SCHEMAS.items()}
    for line_number, line in enumerate(ndjson_path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_type = data.get("event_type")
        if event_type not in schema_cache:
            raise SystemExit(f"Unknown event_type {event_type} on line {line_number}")
        validate_json(data, schema_cache[event_type], f"lifecycle.ndjson:{line_number}")


def main() -> None:
    validate_core_fixtures()
    validate_event_fixtures()
    print("Contracts validated successfully.")


if __name__ == "__main__":
    main()
