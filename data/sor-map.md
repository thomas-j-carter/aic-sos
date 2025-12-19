
# System of Record (SoR) map

**Principle:** External systems remain SoR for business data and identities; our platform is SoR for AI governance, approvals, runtime enforcement decisions, evidence, and metering.

| Entity | System of Record |
|---|---|
| Identity (users, groups) | Customer IdP (Okta / Entra ID) |
| Tickets/incidents | ServiceNow (or JSM/Zendesk) |
| Chat messages | Slack (or Teams later) |
| Repos/PRs | GitHub (or GitLab later) |
| Workflows/agents built through us | Our platform |
| Policies / PolicyBundles | Our platform |
| Approvals / ApprovalArtifacts | Our platform |
| Runs / DecisionRecords / ToolCalls | Our platform |
| Audit logs / Evidence chain | Our platform |
| Metering / Budgets / Quotas | Our platform |
