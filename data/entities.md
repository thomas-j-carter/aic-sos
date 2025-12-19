
# Canonical entities (MVP-trimmed)

## Tenancy
- Tenant
- Workspace
- Environment (dev/test/prod)

## Governance & access
- Principal (Human / ServiceIdentity)
- Role / Permission / RoleBinding
- RiskTier
- PolicyBundle / PolicyRule
- ApprovalRequest / ApprovalDecision / ApprovalArtifact

## Workflows & releases
- Workflow (YAML canonical)
- ArtifactVersion (hash)
- ReleaseCandidate / Deployment

## Connectors
- ConnectorType
- ConnectorArtifact (SemVer)
- ConnectorInstance
- CredentialRef
- ToolAction

## Runtime
- Run / StepExecution
- ToolCall
- DecisionRecord
- HITLTask
- QueueMessage
- IdempotencyKey

## Evidence & FinOps
- AuditLogEvent (hash-chained)
- EvidenceBundle (exportable)
- MeteringRecord / Budget / Quota


---

## DB mapping
For a concrete Postgres sketch + RLS notes, see `data/db-schema.md`.
