
# SLOs & SLIs (MVP)

## Control plane
- **SLO:** 99.5% monthly availability
- **SLIs:** API success rate, p95 latency, auth failures, policy publish success

## Execution plane
- **SLO:** 99.0% monthly availability
- **SLIs:** run success rate, queue oldest-age, DLQ rate, policy fail-closed rate

## Flagship workflow (ITSM triage)
- **SLO (experience):** p95 event→writeback 12–20s; p99 45–90s
- **Backlog cap:** oldest message age < 60 minutes (hard cap)
