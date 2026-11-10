---
id: TASK-043
title: 'Spike: Google tools for OpenClaw and the per-install Google app'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08 17:43'
updated_date: '2026-11-10 23:32'
labels: []
milestone: m-5
dependencies:
  - TASK-041
references:
  - 'https://github.com/taylorwilsdon/google_workspace_mcp'
  - 'https://support.google.com/cloud/answer/7454865'
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: medium
type: spike
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
B1, B2 and B4 need Gmail, Calendar, Drive, Docs and Sheets through the user's own consent (doc-003 AF4). OpenClaw's docs do not mention MCP; the candidates are an OpenClaw plugin or skill, or the workspace-mcp server (multi-user OAuth 2.1), which needs MCP support. D1 also rests on secondary sources (doc-003 P4): that an External Google app, in production and unverified, keeps working past 7 days with restricted Gmail scopes. This spike picks the tool route and tests D1 with the owner's account.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The ways to give OpenClaw Google tools are listed with how each handles per-user OAuth, scopes and stored tokens, and at least two are tried
- [x] #2 A Google Cloud project with an External, unverified OAuth app in production exists for the home install, and its setup steps are written down for the install docs
- [x] #3 With the owner's consent the agent reads mail, creates a draft, reads the calendar, and edits a Sheet and a Doc through the chosen route
- [ ] #4 The token still works more than 7 days after consent, or the failure and the fallback (non-domain users use Google through the sandbox browser) are recorded
- [x] #5 The choice is recorded in doc-004 with a decision record, including whether users consent twice (sign-in in m-6, and the tools)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Routes (AC1), from OpenClaw 2026.9.36's own docs: OpenClaw has full MCP support (mcp.servers: stdio, SSE, streamable HTTP; OAuth sign-in for HTTP servers; per-server tool filters; same tool policy), so the PRD's 'no MCP' premise is wrong. Candidates: (a) bundled gog skill + gogcli (openclaw/gogcli, Go binary) in the sandbox, run by exec; tokens in the sandbox volume (file keyring, password in env). (b) workspace-mcp (Python) as an MCP server outside the sandbox, one container per user behind the gate, so refresh tokens are never readable by the agent; OAuth via its own callback. (c) workspace-mcp as stdio inside the sandbox (tokens in the volume). (d) the agent uses Google in the sandbox browser (fallback). (e) our own TypeScript MCP server later. Try (a) and (b); note (c) from (b).
2. Google Cloud (AC2): an External OAuth app in production, unverified, with the scopes the tasks need (Gmail incl. restricted, Calendar, Drive, Docs, Sheets); setup steps written for the install docs while the owner does them in the console.
3. Trials (AC3): with the chosen account's consent, through each route: read mail, create a draft, read the calendar, edit a Sheet and a Doc. Compare: setup steps, consent screens, where tokens live and who can read them, tool quality with the local model, failure modes.
4. D1 (AC4): record the consent date; check the token after 7+ days (around 2026-11-17); record the result and the fallback if it fails.
5. Decision (AC5): doc-004 and a decision record: chosen route, token storage, and whether users consent twice (m-6 sign-in and the tools).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner's choices (2026-11-09): trials and D1 with the bench test account; the production OAuth app in a new project (local-ai-home), created by the owner in the console (steps given in chat, to become the install docs). Not created yet (owner away; only the local-ai-bench client is in Downloads).
Research (AC1, from the pinned versions' docs):
- OpenClaw: full MCP client (mcp.servers: stdio, SSE, streamable HTTP; OAuth sign-in for HTTP servers via Settings or openclaw mcp login; toolFilter include/exclude; tools go through the normal tool policy). The bundled 'google' plugin is Gemini (models), not Workspace. Bundled skill 'gog' drives gogcli through exec.
- gogcli (openclaw/gogcli, Go, pin v0.47.0 of 2026-10-23): per-account OAuth, platform keyring or encrypted file keyring (password in env) for refresh tokens; least-privilege flags (--readonly, --gmail-no-send, exact command allowlists, --wrap-untrusted for content); 'gog mcp' is a typed stdio MCP server, read-only by default. Key option: GOG_GOOGLE_API_BASE_URL sends all *.googleapis.com calls to a relay that adds credentials, and gog then holds and sends no credentials at all. So gog can run in the sandbox with no token, behind a relay outside the agent's reach (e.g. in the gate), which can also enforce policy (TASK-044).
- workspace-mcp (Python, pin 2.2.0 of 2026-10-23): 120+ tools in tiers (core/extended/complete), --read-only, per-service permissions; single-user (credentials on disk) or OAuth 2.1 multi-user over HTTP (PKCE, its own Google callback), stateless mode, External OAuth provider mode (validates a bearer token obtained elsewhere: a path to one consent with the m-6 sign-in), trusted-gateway identity mode. No telemetry.
Blocked: installing gogcli in the sandbox (download + install) was denied by the permission check; also pending the owner's approval: giving a Google token to a sandbox or a new container. Nothing installed.

2026-11-10: owner created GCP project local-ai-home (Desktop client local-ai-agent, JSON in the owner's Downloads; bench account ercapperones@gmail.com is the support/contact email and a test user). Finding for D1: Publish app stays disabled until Branding is complete; with the required name/emails filled it still is, so production apparently needs the home page and privacy policy links and their authorized domain. Every per-install app would need them: one public project page (e.g. GitHub Pages) that all installs point to would do, since an unverified app's domain is only listed, not proven. A logo forces verification: none. Until the pages exist the app stays in Testing (7-day sign-ins), so the D1 clock has not started; AC3 trials can run in Testing.

2026-11-11 trial (owner-approved: installs, bench sign-in, containers). Consent: ercapperones@gmail.com on local-ai-home (Testing), 2026-11-10 23:06 UTC, one consent for both routes (openid, email, profile, gmail.modify, gmail.settings.basic, calendar, drive, documents, spreadsheets); token in Credential Manager only (spike/task-043/google-consent.ps1).
Setup (spike/task-043/trial.ps1): relay (relay.ts, 'google') and workspace-mcp 2.2.0 ('gws') on the sandbox network only, egress through the gate; gate gained GATE_SERVICES (exact host:port pairs on the sandbox network; tests 12/12) since OpenClaw's managed proxy has no bypass and sends MCP as CONNECT gws:8000; sandbox.ps1 -Services.
Route (a) gog 0.47.0 + relay: 5/5 (mail 57 s, draft 32 s, calendar 12 s, sheet 15 s, doc 52 s). gog accepts plain-HTTP relay URL on a non-loopback host. The doc edit needed a hint (gog docs write --append): first try the agent wrongly said gog cannot edit and used the MCP tools. Relay refuses send (also drafts/send), DELETE, trash, Drive sharing; path rules missed Drive trash (PATCH {trashed:true}) - the relay now reads Drive metadata bodies (TASK-044: rules must see bodies).
Route (b) workspace-mcp: 5/5 (mail 7 s, draft 25 s, calendar 21 s, sheet 9 s, doc 32 s); core tier has no draft tool but has send_gmail_message, so extended tier with send/sharing/filter tools disabled on the server. The sandbox can call workspace-mcp directly (curl gws:8000, no MCP auth in single-user mode), bypassing OpenClaw's tool policy: only server-side limits count. manage_event creates/updates/deletes in one tool, so calendar delete cannot be removed alone.
No Google token in the sandbox (files, env) or in the relay/gws/gate logs.
Pages: lucacaputo/local-ai-privacy-pages (public, owner-approved; commit re-authored to the GitHub no-reply address): https://lucacaputo.github.io/local-ai-privacy-pages/ and /privacy.html. Next: Branding links + authorized domain lucacaputo.github.io, publish, re-consent, D1 clock.

2026-11-11: app local-ai-home published (In production, unverified, Branding with the GitHub Pages links). Re-consent on the published app: ercapperones@gmail.com, 2026-11-10 23:24 UTC (D1 clock starts; a Testing token would die by 2026-11-17 23:24 UTC). Recheck on or after 2026-11-18 that the relay still refreshes (docker logs openclaw-owner-google: 'refreshed', not invalid_grant). Both routes work on the new token.

2026-11-11: AC1 (routes listed in doc-004 decision-016, (a) and (b) tried), AC2 (local-ai-home published; docs/google-app.md) and AC3 (both routes 5/5) checked. AC5 waits for the owner to accept decision-016 (filed as proposed; owner chose to keep version pins). AC4 waits for the D1 check from 2026-11-18.

2026-11-11: owner accepted decision-016.
<!-- SECTION:NOTES:END -->
