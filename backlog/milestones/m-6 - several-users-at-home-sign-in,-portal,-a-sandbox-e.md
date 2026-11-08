---
id: m-6
title: "Several users at home: sign-in, portal, a sandbox each"
---

## Description

## Description

Turn the single-user agent of m-5 into the multi-user setup of doc-003 on the home install: Caddy behind tailscale serve, oauth2-proxy with the install's own Google app (D1, with the P4 checks), and the TypeScript portal (decision-012) that maps each signed-in user to their own container, starts and sleeps containers under the RAM cap, queues users over it, and resets a sandbox on request.

Done when: two users (the owner and a household member) each work in their own sandbox at the same time, B1 passes for both at once, and the isolation tests (doc-003 A3) pass.

Out of scope: scheduled tasks and notifications, the office network, machine detection in the install.
