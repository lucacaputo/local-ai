---
id: TASK-013
title: Remote acceptance run and Tailscale ACL
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 21:00'
updated_date: '2026-10-18 21:47'
labels: []
milestone: m-1
dependencies:
  - TASK-011
  - TASK-012
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The MVP only tested from the PC itself. The PRD acceptance criteria require /model and both model families to work from a remote tailnet device, and the Tailscale ACL should limit the router port to the users own devices (carry-over from the MVP run).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 From the second device, /model lists Claude models plus Local Coder and Local Light, and a prompt works on local-coder and on a Claude model with the subscription login
- [x] #2 A multi-step edit task completes from the second device with local-coder
- [x] #3 Tailscale ACL restricts port 4000 on the PC to the users own devices, and the policy is recorded in doc-002
- [x] #4 ai-down makes the router unreachable from the second device
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Bring the stack up on the PC (it was down) and package the ts-demo repo (reset) for the Mac, sent with Taildrop.
2. Mac run by the user, from scripts/mac/claude-local.sh: /model lists Claude + Local Coder + Local Light; one prompt on local-coder and one on a Claude model; the multi-step edit task on local-coder (npm test passes).
3. ACL: draft a tailnet policy that allows only the user's own devices to reach tcp:4000 on the PC; the user applies it in the admin console (no API token here); re-check the Mac still works and a device outside it would not.
4. ai-down on the PC, then the Mac reachability check must fail.
5. Record the policy and results in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mac run by the user (results reported by them): /model, local-coder and Claude prompts, multi-step ts-demo edit with npm test passing. ACL grant applied in the admin console and the Mac still got 401 from the router. After ai-down the Mac request failed (000). The ACL denial path (a device outside the policy) was not exercised: there is no such device. Results in doc-002.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Remote acceptance passed from a Mac over Tailscale: /model lists Claude plus Local Coder and Local Light, local-coder and a Claude model answer, and the multi-step ts-demo edit completes with passing tests. Tailscale ACL now has a single grant, autogroup:member to autogroup:self on tcp:4000 (allow-all removed), recorded in doc-002; the router stays reachable from the Mac and is unreachable after ai-down. Limits: the denial side of the ACL was not tested for lack of a foreign device, and results were reported by the user, not measured by the harness. Next: TASK-014 (LAN and internet scan, A4).
<!-- SECTION:FINAL_SUMMARY:END -->
