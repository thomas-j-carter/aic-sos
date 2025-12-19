
# Privacy & compliance posture (MVP)

- Default: metadata-only evidence; no content storage/indexing
- Region pinning: US + EU; no cross-region replication by default
- Retention:
  - runtime traces/logs: 14 days default (configurable 30)
  - audit evidence: years-long (configurable; common 3–7 years)
- Deletion:
  - append-only audit logs; corrections via superseding events
  - redaction represented as redaction events + content removal where applicable
- DPA/GDPR-aligned operations (MVP), SOC2 program starts early; Type I targeted for v1
