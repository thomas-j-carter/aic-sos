
package policy

default decision := "DENY"

# Inputs expected:
# input.actor, input.scope, input.action, input.governance, input.operational
# input.action.tool_action_id, input.action.risk_labels, input.action.requested_scopes

# Allow read actions by default only if explicitly allowlisted
allowlisted_tool_actions := {
  "servicenow.get_incident",
  "github.get_pull_request"
}

# Writes require HITL unless policy says otherwise; MVP: reversible writes allowed with caps
reversible_writes := {
  "servicenow.update_incident_reversible",
  "servicenow.add_work_note",
  "slack.post_message",
  "slack.post_approval_request",
  "github.post_pr_comment"
}

# Example: Require step-up for scope changes and high-risk actions
require_step_up {
  input.action.action_type == "connector_scope_change"
}

# Example: Require HITL for all writes in high risk tier
require_hitl {
  input.governance.risk_tier == "high"
  input.action.tool_action_id in reversible_writes
}

allow {
  input.action.tool_action_id in allowlisted_tool_actions
  input.actor.authenticated == true
}

allow {
  # reversible writes allowed in low/medium only after approval artifact present
  input.action.tool_action_id in reversible_writes
  input.governance.risk_tier != "high"
  input.governance.approval_artifact_present == true
  input.operational.within_write_caps == true
  input.actor.authenticated == true
}

decision := "REQUIRE_STEP_UP" { require_step_up }
decision := "REQUIRE_HITL" { require_hitl }
decision := "ALLOW" { allow }
