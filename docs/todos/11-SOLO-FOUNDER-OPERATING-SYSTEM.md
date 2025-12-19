# Solo Founder Operating System (MVP)

You are a 1-person team, so the goal is to **sequence** work to keep forward progress on the demo path while avoiding “enterprise yak-shaves”.
This file gives a practical cadence to execute the TODO set.

## P0 / Critical

- [ ] **Keep WIP ≤ 2**: one “platform” task + one “workflow” task at a time; everything else goes to backlog.
- [ ] **Run weekly “demo drill”**: every week, run the ServiceNow → HITL → writeback → evidence bundle path end-to-end in a staging tenant.
- [ ] **Default to managed services** (AWS): minimize custom infra; avoid self-hosting anything in MVP unless forced.
- [ ] **Ship thin vertical slices**: implement the smallest end-to-end slice, then harden/expand.
- [ ] **One source of truth for scope**: P0s in phase files + the Critical Path file. Anything else is explicitly “post-MVP”.

## P1 / High

- [ ] Set a **weekly theme** (example): 
  - Week theme = “Tenancy + Auth”, “Agent + ServiceNow”, “Workflow engine + approvals”, “Audit/evidence + reporting”, “Hardening + launch”.
- [ ] Use a **single environment ladder**: local → dev → staging → prod (no extra environments).
- [ ] Maintain a **demo dataset / replay** (fixtures) so you can reproduce issues quickly.

## P2 / Medium

- [ ] Establish a “definition of done” gate for each PR:
  - [ ] Unit tests updated (or explicitly N/A)
  - [ ] Integration test updated (if connector/runtime touched)
  - [ ] Contract/API docs updated
  - [ ] Changelog entry (if user-facing behavior changed)

## P3 / Low

- [ ] Keep a lightweight “decision log” section at the top of the RFC to avoid re-deciding.
