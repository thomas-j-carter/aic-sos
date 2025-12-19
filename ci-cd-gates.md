
# CI/CD gates (MVP)

Required to merge:
- lint/format + unit tests per service
- OpenAPI lint + diff checks
- JSON Schema validation for event contracts
- Rego policy regression tests (OPA test)
- Connector fixture tests (recorded responses / sandbox)
- SAST + dependency scan + container scan

Required to deploy:
- all above green
- migration checks (db)
- policy bundle signed + verifiable
- connector manifest validated (ToolActions, scopes, schemas present)
