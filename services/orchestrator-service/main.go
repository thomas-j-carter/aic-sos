package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type RunRecord struct {
	RunID              string `json:"run_id"`
	TenantID           string `json:"tenant_id"`
	CorrelationID      string `json:"correlation_id"`
	Actor              string `json:"actor"`
	PolicySnapshotHash string `json:"policy_snapshot_hash"`
	ApprovalRequired   bool   `json:"approval_required"`
	Status             string `json:"status"`
	ApprovalTokenID    string `json:"approval_token_id,omitempty"`
	UpdatedAt          string `json:"updated_at"`
}

type ApprovalToken struct {
	TokenID            string `json:"token_id"`
	PolicySnapshotHash string `json:"policy_snapshot_hash"`
	IssuedAt           string `json:"issued_at"`
}

type EvaluatePolicyResponse struct {
	Status           string `json:"status"`
	Decision         string `json:"decision"`
	ApprovalRequired bool   `json:"approval_required"`
	PolicySnapshot   string `json:"policy_snapshot_hash"`
	ReasonCode       string `json:"reason_code,omitempty"`
}

type IssueApprovalTokenResponse struct {
	Status string        `json:"status"`
	Token  ApprovalToken `json:"token"`
}

type ExecuteRunResponse struct {
	ExecutionResult struct {
		Status     string `json:"status"`
		ReasonCode string `json:"reason_code,omitempty"`
	} `json:"execution_result"`
}

type Event struct {
	EventType     string                 `json:"event_type"`
	OccurredAt    string                 `json:"occurred_at"`
	TenantID      string                 `json:"tenant_id"`
	CorrelationID string                 `json:"correlation_id"`
	Actor         string                 `json:"actor"`
	Payload       map[string]interface{} `json:"payload"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run . <trigger-ticket|approve|status|demo-mismatch> [run_id]")
		os.Exit(1)
	}

	command := os.Args[1]
	switch command {
	case "trigger-ticket":
		runID, err := triggerTicket()
		if err != nil {
			exitWithError(err)
		}
		fmt.Println(runID)
	case "approve":
		if len(os.Args) < 3 {
			exitWithError(errors.New("approve requires run_id"))
		}
		if err := approveRun(os.Args[2]); err != nil {
			exitWithError(err)
		}
	case "status":
		if len(os.Args) < 3 {
			exitWithError(errors.New("status requires run_id"))
		}
		if err := showStatus(os.Args[2]); err != nil {
			exitWithError(err)
		}
	case "demo-mismatch":
		if err := demoMismatch(); err != nil {
			exitWithError(err)
		}
	default:
		exitWithError(fmt.Errorf("unknown command: %s", command))
	}
}

func exitWithError(err error) {
	fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	os.Exit(1)
}

func now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func repoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	return filepath.Dir(filepath.Dir(filepath.Dir(wd))), nil
}

func localDir() (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, ".astraai", "local"), nil
}

func runsDir() (string, error) {
	dir, err := localDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "runs"), nil
}

func ensureLocalDirs() (string, error) {
	dir, err := localDir()
	if err != nil {
		return "", err
	}
	runs := filepath.Join(dir, "runs")
	if err := os.MkdirAll(runs, 0o755); err != nil {
		return "", err
	}
	return dir, nil
}

func eventsPath() (string, error) {
	dir, err := localDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "events.ndjson"), nil
}

func generateID(prefix string) (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return fmt.Sprintf("%s_%s", prefix, hex.EncodeToString(buf)), nil
}

func coreBinary() (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, "core", "target", "debug", "astraai-core"), nil
}

func callCore(command string, payload interface{}, out interface{}) error {
	bin, err := coreBinary()
	if err != nil {
		return err
	}
	input, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	cmd := exec.Command(bin, command)
	cmd.Stdin = bytes.NewReader(input)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("core error: %v: %s", err, stderr.String())
	}
	if out != nil {
		if err := json.Unmarshal(stdout.Bytes(), out); err != nil {
			return err
		}
	}
	return nil
}

func writeRun(record RunRecord) error {
	runs, err := runsDir()
	if err != nil {
		return err
	}
	path := filepath.Join(runs, record.RunID+".json")
	record.UpdatedAt = now()
	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func readRun(runID string) (RunRecord, error) {
	runs, err := runsDir()
	if err != nil {
		return RunRecord{}, err
	}
	path := filepath.Join(runs, runID+".json")
	data, err := os.ReadFile(path)
	if err != nil {
		return RunRecord{}, err
	}
	var record RunRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return RunRecord{}, err
	}
	return record, nil
}

func appendEvent(event Event) error {
	if event.TenantID == "" || event.CorrelationID == "" || event.Actor == "" {
		return errors.New("event missing tenant_id, correlation_id, or actor")
	}
	path, err := eventsPath()
	if err != nil {
		return err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer file.Close()
	payload, err := json.Marshal(event)
	if err != nil {
		return err
	}
	if _, err := file.Write(append(payload, '\n')); err != nil {
		return err
	}
	return nil
}

func triggerTicket() (string, error) {
	if _, err := ensureLocalDirs(); err != nil {
		return "", err
	}
	runID, err := generateID("run")
	if err != nil {
		return "", err
	}
	tenantID := "tenant_local"
	actor := "user:demo"
	correlationID := "corr_" + runID
	policySnapshot := "snap_" + runID

	record := RunRecord{
		RunID:              runID,
		TenantID:           tenantID,
		CorrelationID:      correlationID,
		Actor:              actor,
		PolicySnapshotHash: policySnapshot,
		Status:             "created",
	}

	if err := writeRun(record); err != nil {
		return "", err
	}

	if err := appendEvent(Event{
		EventType:     "run.created",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         actor,
		Payload: map[string]interface{}{
			"run_id":               runID,
			"policy_snapshot_hash": policySnapshot,
		},
	}); err != nil {
		return "", err
	}

	if err := appendEvent(Event{
		EventType:     "run.policy.requested",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id":               runID,
			"policy_snapshot_hash": policySnapshot,
		},
	}); err != nil {
		return "", err
	}

	request := map[string]interface{}{
		"tenant_id":            tenantID,
		"correlation_id":       correlationID,
		"actor":                actor,
		"run_id":               runID,
		"policy_snapshot_hash": policySnapshot,
		"risk_level":           "high",
	}

	var response EvaluatePolicyResponse
	if err := callCore("EvaluatePolicy", request, &response); err != nil {
		return "", err
	}

	if err := appendEvent(Event{
		EventType:     "run.policy.decided",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:policy",
		Payload: map[string]interface{}{
			"run_id":               runID,
			"decision":             response.Decision,
			"approval_required":    response.ApprovalRequired,
			"policy_snapshot_hash": response.PolicySnapshot,
			"reason_code":          response.ReasonCode,
		},
	}); err != nil {
		return "", err
	}

	record.ApprovalRequired = response.ApprovalRequired
	if response.ApprovalRequired {
		record.Status = "awaiting_approval"
		if err := appendEvent(Event{
			EventType:     "run.paused.awaiting_approval",
			OccurredAt:    now(),
			TenantID:      tenantID,
			CorrelationID: correlationID,
			Actor:         "system:orchestrator",
			Payload: map[string]interface{}{
				"run_id":      runID,
				"reason_code": response.ReasonCode,
			},
		}); err != nil {
			return "", err
		}

		if err := writeRun(record); err != nil {
			return "", err
		}
		return runID, nil
	}

	return runID, executeRunFlow(&record, nil)
}

func approveRun(runID string) error {
	if _, err := ensureLocalDirs(); err != nil {
		return err
	}
	record, err := readRun(runID)
	if err != nil {
		return err
	}
	if record.Status != "awaiting_approval" {
		return fmt.Errorf("run %s is not awaiting approval", runID)
	}

	request := map[string]interface{}{
		"tenant_id":            record.TenantID,
		"correlation_id":       record.CorrelationID,
		"actor":                "approver:demo",
		"run_id":               record.RunID,
		"policy_snapshot_hash": record.PolicySnapshotHash,
	}

	var response IssueApprovalTokenResponse
	if err := callCore("IssueApprovalToken", request, &response); err != nil {
		return err
	}

	record.ApprovalTokenID = response.Token.TokenID
	if err := appendEvent(Event{
		EventType:     "run.approved",
		OccurredAt:    now(),
		TenantID:      record.TenantID,
		CorrelationID: record.CorrelationID,
		Actor:         "approver:demo",
		Payload: map[string]interface{}{
			"run_id":               record.RunID,
			"approval_token_id":    response.Token.TokenID,
			"policy_snapshot_hash": response.Token.PolicySnapshotHash,
		},
	}); err != nil {
		return err
	}

	return executeRunFlow(&record, &response.Token)
}

func executeRunFlow(record *RunRecord, token *ApprovalToken) error {
	if err := appendEvent(Event{
		EventType:     "run.started",
		OccurredAt:    now(),
		TenantID:      record.TenantID,
		CorrelationID: record.CorrelationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id": record.RunID,
		},
	}); err != nil {
		return err
	}

	request := map[string]interface{}{
		"tenant_id":            record.TenantID,
		"correlation_id":       record.CorrelationID,
		"actor":                "system:orchestrator",
		"run_id":               record.RunID,
		"policy_snapshot_hash": record.PolicySnapshotHash,
	}
	if token != nil {
		request["approval_token"] = token
	}

	var response ExecuteRunResponse
	if err := callCore("ExecuteRun", request, &response); err != nil {
		return err
	}

	if response.ExecutionResult.Status == "failed" {
		record.Status = "failed"
		if err := appendEvent(Event{
			EventType:     "run.failed",
			OccurredAt:    now(),
			TenantID:      record.TenantID,
			CorrelationID: record.CorrelationID,
			Actor:         "system:orchestrator",
			Payload: map[string]interface{}{
				"run_id":           record.RunID,
				"reason_code":      response.ExecutionResult.ReasonCode,
				"execution_status": "failed",
			},
		}); err != nil {
			return err
		}
		return writeRun(*record)
	}

	record.Status = "completed"
	if err := appendEvent(Event{
		EventType:     "run.completed",
		OccurredAt:    now(),
		TenantID:      record.TenantID,
		CorrelationID: record.CorrelationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id":           record.RunID,
			"execution_status": "succeeded",
		},
	}); err != nil {
		return err
	}
	return writeRun(*record)
}

func showStatus(runID string) error {
	record, err := readRun(runID)
	if err != nil {
		return err
	}
	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return err
	}
	fmt.Println(string(data))

	path, err := eventsPath()
	if err != nil {
		return err
	}
	file, err := os.Open(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			fmt.Println("No events.ndjson found.")
			return nil
		}
		return err
	}
	defer file.Close()

	var lines []string
	reader := bufio.NewScanner(file)
	for reader.Scan() {
		line := reader.Text()
		if strings.Contains(line, fmt.Sprintf("\"run_id\":\"%s\"", runID)) {
			lines = append(lines, line)
		}
	}
	if err := reader.Err(); err != nil {
		return err
	}

	if len(lines) == 0 {
		fmt.Println("No events found for run.")
		return nil
	}

	start := 0
	if len(lines) > 5 {
		start = len(lines) - 5
	}
	fmt.Println("Recent events:")
	for _, line := range lines[start:] {
		fmt.Println(line)
	}
	return nil
}

func demoMismatch() error {
	if _, err := ensureLocalDirs(); err != nil {
		return err
	}
	runID, err := generateID("run")
	if err != nil {
		return err
	}
	tenantID := "tenant_demo"
	actor := "user:mismatch"
	correlationID := "corr_" + runID
	policySnapshot := "snap_" + runID

	record := RunRecord{
		RunID:              runID,
		TenantID:           tenantID,
		CorrelationID:      correlationID,
		Actor:              actor,
		PolicySnapshotHash: policySnapshot,
		Status:             "created",
		ApprovalRequired:   true,
	}

	if err := writeRun(record); err != nil {
		return err
	}

	if err := appendEvent(Event{
		EventType:     "run.created",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         actor,
		Payload: map[string]interface{}{
			"run_id":               runID,
			"policy_snapshot_hash": policySnapshot,
		},
	}); err != nil {
		return err
	}

	if err := appendEvent(Event{
		EventType:     "run.policy.requested",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id":               runID,
			"policy_snapshot_hash": policySnapshot,
		},
	}); err != nil {
		return err
	}

	policyRequest := map[string]interface{}{
		"tenant_id":            tenantID,
		"correlation_id":       correlationID,
		"actor":                actor,
		"run_id":               runID,
		"policy_snapshot_hash": policySnapshot,
		"risk_level":           "high",
	}

	var policyResponse EvaluatePolicyResponse
	if err := callCore("EvaluatePolicy", policyRequest, &policyResponse); err != nil {
		return err
	}

	if err := appendEvent(Event{
		EventType:     "run.policy.decided",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:policy",
		Payload: map[string]interface{}{
			"run_id":               runID,
			"decision":             policyResponse.Decision,
			"approval_required":    policyResponse.ApprovalRequired,
			"policy_snapshot_hash": policyResponse.PolicySnapshot,
			"reason_code":          policyResponse.ReasonCode,
		},
	}); err != nil {
		return err
	}

	if policyResponse.ApprovalRequired {
		if err := appendEvent(Event{
			EventType:     "run.paused.awaiting_approval",
			OccurredAt:    now(),
			TenantID:      tenantID,
			CorrelationID: correlationID,
			Actor:         "system:orchestrator",
			Payload: map[string]interface{}{
				"run_id":      runID,
				"reason_code": policyResponse.ReasonCode,
			},
		}); err != nil {
			return err
		}
	}

	tokenRequest := map[string]interface{}{
		"tenant_id":            tenantID,
		"correlation_id":       correlationID,
		"actor":                "approver:mismatch",
		"run_id":               runID,
		"policy_snapshot_hash": policySnapshot,
	}

	var tokenResponse IssueApprovalTokenResponse
	if err := callCore("IssueApprovalToken", tokenRequest, &tokenResponse); err != nil {
		return err
	}

	if err := appendEvent(Event{
		EventType:     "run.approved",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "approver:mismatch",
		Payload: map[string]interface{}{
			"run_id":               runID,
			"approval_token_id":    tokenResponse.Token.TokenID,
			"policy_snapshot_hash": tokenResponse.Token.PolicySnapshotHash,
		},
	}); err != nil {
		return err
	}

	if err := appendEvent(Event{
		EventType:     "run.started",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id": runID,
		},
	}); err != nil {
		return err
	}

	mismatchedRequest := map[string]interface{}{
		"tenant_id":            tenantID,
		"correlation_id":       correlationID,
		"actor":                "system:orchestrator",
		"run_id":               runID,
		"policy_snapshot_hash": policySnapshot + "_mismatch",
		"approval_token":       tokenResponse.Token,
	}

	var executeResponse ExecuteRunResponse
	if err := callCore("ExecuteRun", mismatchedRequest, &executeResponse); err != nil {
		return err
	}

	if executeResponse.ExecutionResult.Status != "failed" {
		return fmt.Errorf("expected failure but got status %s", executeResponse.ExecutionResult.Status)
	}

	record.Status = "failed"
	if err := appendEvent(Event{
		EventType:     "run.failed",
		OccurredAt:    now(),
		TenantID:      tenantID,
		CorrelationID: correlationID,
		Actor:         "system:orchestrator",
		Payload: map[string]interface{}{
			"run_id":           runID,
			"reason_code":      executeResponse.ExecutionResult.ReasonCode,
			"execution_status": "failed",
		},
	}); err != nil {
		return err
	}

	if err := writeRun(record); err != nil {
		return err
	}

	fmt.Printf("Demo mismatch run_id=%s reason_code=%s\n", runID, executeResponse.ExecutionResult.ReasonCode)
	return nil
}
