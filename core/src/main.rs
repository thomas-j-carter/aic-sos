use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::env;
use std::io::{self, Read};

#[derive(Deserialize)]
struct EvaluatePolicyRequest {
    tenant_id: String,
    correlation_id: String,
    actor: String,
    run_id: String,
    policy_snapshot_hash: String,
    risk_level: String,
}

#[derive(Serialize)]
struct EvaluatePolicyResponse {
    status: String,
    decision: String,
    approval_required: bool,
    policy_snapshot_hash: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason_code: Option<String>,
}

#[derive(Deserialize)]
struct IssueApprovalTokenRequest {
    tenant_id: String,
    correlation_id: String,
    actor: String,
    run_id: String,
    policy_snapshot_hash: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct ApprovalToken {
    token_id: String,
    policy_snapshot_hash: String,
    issued_at: String,
}

#[derive(Serialize)]
struct IssueApprovalTokenResponse {
    status: String,
    token: ApprovalToken,
}

#[derive(Deserialize)]
struct ExecuteRunRequest {
    tenant_id: String,
    correlation_id: String,
    actor: String,
    run_id: String,
    policy_snapshot_hash: String,
    #[serde(default)]
    approval_token: Option<ApprovalToken>,
    #[serde(default)]
    force_fail: Option<bool>,
}

#[derive(Serialize)]
struct ExecutionResult {
    status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason_code: Option<String>,
}

#[derive(Serialize)]
struct ExecuteRunResponse {
    execution_result: ExecutionResult,
}

fn read_stdin() -> Result<String, io::Error> {
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer)?;
    Ok(buffer)
}

fn evaluate_policy(input: &str) -> Result<String, serde_json::Error> {
    let request: EvaluatePolicyRequest = serde_json::from_str(input)?;
    let approval_required = request.risk_level == "high";
    let response = EvaluatePolicyResponse {
        status: "ok".to_string(),
        decision: if approval_required {
            "approve_required".to_string()
        } else {
            "allow".to_string()
        },
        approval_required,
        policy_snapshot_hash: request.policy_snapshot_hash,
        reason_code: if approval_required {
            Some("APPROVAL_REQUIRED_HIGH_RISK".to_string())
        } else {
            None
        },
    };
    serde_json::to_string(&response)
}

fn issue_approval_token(input: &str) -> Result<String, serde_json::Error> {
    let request: IssueApprovalTokenRequest = serde_json::from_str(input)?;
    let token = ApprovalToken {
        token_id: format!("token_{}", request.run_id),
        policy_snapshot_hash: request.policy_snapshot_hash,
        issued_at: Utc::now().to_rfc3339(),
    };
    let response = IssueApprovalTokenResponse {
        status: "ok".to_string(),
        token,
    };
    serde_json::to_string(&response)
}

fn execute_run(input: &str) -> Result<String, serde_json::Error> {
    let request: ExecuteRunRequest = serde_json::from_str(input)?;
    if let Some(token) = &request.approval_token {
        if token.policy_snapshot_hash != request.policy_snapshot_hash {
            let response = ExecuteRunResponse {
                execution_result: ExecutionResult {
                    status: "failed".to_string(),
                    reason_code: Some("POLICY_SNAPSHOT_MISMATCH".to_string()),
                },
            };
            return serde_json::to_string(&response);
        }
    }

    let failed = request.force_fail.unwrap_or(false);
    let response = ExecuteRunResponse {
        execution_result: if failed {
            ExecutionResult {
                status: "failed".to_string(),
                reason_code: Some("EXECUTION_FAILED".to_string()),
            }
        } else {
            ExecutionResult {
                status: "succeeded".to_string(),
                reason_code: None,
            }
        },
    };
    serde_json::to_string(&response)
}

fn main() {
    let mut args = env::args().skip(1);
    let command = args.next().unwrap_or_default();
    if command.is_empty() {
        eprintln!("Usage: astraai-core <EvaluatePolicy|IssueApprovalToken|ExecuteRun>");
        std::process::exit(1);
    }

    let input = match read_stdin() {
        Ok(data) => data,
        Err(err) => {
            eprintln!("Failed to read stdin: {err}");
            std::process::exit(1);
        }
    };

    let result = match command.as_str() {
        "EvaluatePolicy" => evaluate_policy(&input),
        "IssueApprovalToken" => issue_approval_token(&input),
        "ExecuteRun" => execute_run(&input),
        _ => {
            eprintln!("Unknown command: {command}");
            std::process::exit(1);
        }
    };

    match result {
        Ok(output) => println!("{output}"),
        Err(err) => {
            eprintln!("Failed to process {command}: {err}");
            std::process::exit(1);
        }
    }
}
