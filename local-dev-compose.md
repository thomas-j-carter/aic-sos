
# Local dev (docker-compose)

Minimum: Postgres + local queue emulator + OTel collector + services.

MVP command:
- `docker compose up`
- `make demo-itsm` to run the vertical slice against stubs/fixtures

Notes:
- Do not store raw customer content in local logs by default.
