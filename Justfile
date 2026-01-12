set shell := ["/usr/bin/env", "bash", "-eu", "-o", "pipefail", "-c"]

fmt:
    (cd services/orchestrator-service && gofmt -w .)
    (cd core && cargo fmt)

check:
    python3 scripts/validate_contracts.py
    python3 scripts/check_contract_map.py
    python3 scripts/check_reason_codes.py
    python3 scripts/check_lifecycle_sequence.py
    python3 scripts/check_snapshot_integrity.py
    python3 scripts/check_local_events_ndjson.py
    (cd services/orchestrator-service && go test ./...)
    (cd core && cargo test)

demo:
    (cd core && cargo build)
    run_id=$(cd services/orchestrator-service && go run . trigger-ticket)
    (cd services/orchestrator-service && go run . approve "$run_id")
    (cd services/orchestrator-service && go run . demo-mismatch)
