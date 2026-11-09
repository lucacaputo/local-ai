# Agent sandbox image (TASK-041, decision-010/011): OpenClaw with Chromium, a shell and the office file libraries.
# One container per user; the container is the sandbox, so OpenClaw's own tool sandbox stays off.
# Built by scripts\sandbox.ps1 build (context: the repo root, see Dockerfile.dockerignore).

# OpenClaw's own image, extended-stable line, with Playwright's Chromium (Node 24.22.1, Python 3.11, Debian bookworm)
FROM ghcr.io/openclaw/openclaw:2026.9.36-browser@sha256:3cdd7bcfb9c04b76a4af7790d2c0a2b241e29a0ebebea11905d0e787568cae76

# install.ps1 compares this label with versions.psd1 (Sandbox.OpenClaw)
LABEL local-ai.openclaw="2026.9.36"
USER root

# Office libraries in a venv on PATH, installed from the hash-locked file with the repo's pinned uv (versions.psd1)
COPY --from=ghcr.io/astral-sh/uv:0.13.1@sha256:4a1f3666816dafadd20ceb71eac9a7d56d7ef30279f7d64048519ab901ada336 /uv /usr/local/bin/uv
COPY sandbox/requirements.txt /opt/sandbox/requirements.txt
RUN uv venv --python /usr/bin/python3 /opt/py \
 && uv pip install --python /opt/py/bin/python --require-hashes --no-deps -r /opt/sandbox/requirements.txt \
 && rm /usr/local/bin/uv

# The browsers move out of /home/node, which becomes the user's volume and would hide them.
RUN mv /home/node/.cache/ms-playwright /opt/ms-playwright && chown -R root:root /opt/ms-playwright && chmod -R a+rX /opt/ms-playwright

# Policy comes from the repo, read-only: the agent runs as node and cannot change its own tools or plugins.
COPY config/openclaw.json5 /etc/openclaw/openclaw.json5
RUN chmod 0444 /etc/openclaw/openclaw.json5 && mkdir -p /home/node/work && chown node:node /home/node/work

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    PATH=/opt/py/bin:$PATH \
    OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json5 \
    OPENCLAW_CONFIG_READONLY=1 \
    OPENCLAW_STATE_DIR=/home/node/.openclaw

USER node
WORKDIR /home/node/work
EXPOSE 18789
# Same check and timings as the base image, by absolute path: its own is relative to /app, the old WORKDIR
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 CMD ["node", "/app/dist/docker-healthcheck.js"]
# The image's own entrypoint runs `openclaw doctor --fix` first, which needs a writable config; with the config
# pinned read-only the gateway starts directly. On a version bump, run doctor once without OPENCLAW_CONFIG_READONLY.
ENTRYPOINT ["tini", "-s", "--"]
CMD ["node", "/app/openclaw.mjs", "gateway"]
