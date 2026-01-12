#!/usr/bin/env python3
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
CONTRACTS_DIR = BASE_DIR / "contracts"


def extract_reason_code_enums(schema: dict) -> list:
    enums = []
    stack = [schema]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            if "reason_code" in node and isinstance(node["reason_code"], dict):
                enum = node["reason_code"].get("enum")
                if enum:
                    enums.append(enum)
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return enums


def main() -> None:
    reason_codes_path = CONTRACTS_DIR / "reason_codes.json"
    reason_codes = json.loads(reason_codes_path.read_text(encoding="utf-8"))["reason_codes"]
    reason_set = set(reason_codes)

    if len(reason_codes) != len(reason_set):
        raise SystemExit("Duplicate reason codes detected in reason_codes.json")

    missing_enum = []
    invalid_codes = []

    schema_paths = list((CONTRACTS_DIR / "core_api").glob("*.schema.json")) + list(
        (CONTRACTS_DIR / "events").glob("*.schema.json")
    )

    for schema_path in schema_paths:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        enums = extract_reason_code_enums(schema)
        if not enums:
            continue
        for enum in enums:
            if not enum:
                missing_enum.append(schema_path.name)
                continue
            invalid = set(enum) - reason_set
            if invalid:
                invalid_codes.append(f"{schema_path.name}: {sorted(invalid)}")

    if missing_enum or invalid_codes:
        messages = []
        if missing_enum:
            messages.append("Schemas with empty reason_code enum: " + ", ".join(missing_enum))
        if invalid_codes:
            messages.append("Invalid reason_code values:\n" + "\n".join(invalid_codes))
        raise SystemExit("\n".join(messages))

    print("Reason codes validated across schemas.")


if __name__ == "__main__":
    main()
