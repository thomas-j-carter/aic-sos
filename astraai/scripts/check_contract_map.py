#!/usr/bin/env python3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
CONTRACTS_DIR = BASE_DIR / "contracts"
CONTRACT_MAP = CONTRACTS_DIR / "CONTRACT_MAP.md"


def main() -> None:
    map_text = CONTRACT_MAP.read_text(encoding="utf-8")
    missing = []

    for schema_path in sorted((CONTRACTS_DIR / "core_api").glob("*.schema.json")):
        rel_path = schema_path.relative_to(CONTRACTS_DIR)
        if str(rel_path) not in map_text:
            missing.append(str(rel_path))

    for schema_path in sorted((CONTRACTS_DIR / "events").glob("*.schema.json")):
        rel_path = schema_path.relative_to(CONTRACTS_DIR)
        event_type = schema_path.stem.replace(".schema", "")
        if str(rel_path) not in map_text or event_type not in map_text:
            missing.append(f"{event_type} ({rel_path})")

    if missing:
        formatted = "\n".join(f"- {item}" for item in missing)
        raise SystemExit(f"Missing entries in CONTRACT_MAP.md:\n{formatted}")

    print("CONTRACT_MAP.md contains all schema entries.")


if __name__ == "__main__":
    main()
