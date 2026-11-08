---
id: m-8
title: "Any PC, and the office server"
---

## Description

## Description

Make the install machine-agnostic (doc-003 AF9, decision-013) and deploy it on the office PC (RTX 4090 24 GB, 64 GB RAM): the install detects the GPU and RAM and picks the model entry, slots, window and sandbox cap; a 24 GB model entry is added to the tested list; the office-network option serves the web page under a company subdomain with a Let's Encrypt certificate through DNS validation (D3, P11); the owner administers the office install over the tailnet. Merged with the office deployment at the user's request (2026-11-08).

Done when: a fresh clone installs on both PCs with nothing machine-specific edited (A1); on the office install B1-B6 pass with 3 users at once, each task under 10 minutes (A2); only the HTTPS sign-in page is reachable from the office network (A4); the coding stack passes t1 on both installs (A5); the office install updates and restarts over the tailnet (A6).

Out of scope: a Mac desktop app, macOS hosts, backups.
