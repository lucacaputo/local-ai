# TASK-043 trial, route (b): workspace-mcp 2.2.0 (2026-10-23) in a container of its own on the sandbox network,
# single-user, streamable HTTP on :8000. Not hash-locked (a trial): dependencies resolved with nothing newer than
# 2026-10-28, two weeks before the trial. Its Google traffic goes through the gate (HTTPS_PROXY); pysocks lets
# httplib2, which the Google API client uses, honour that.
# Built by spike\task-043\trial.ps1 (context: this folder).
FROM python:3.12.12-slim-bookworm@sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c
COPY --from=ghcr.io/astral-sh/uv:0.13.1@sha256:4a1f3666816dafadd20ceb71eac9a7d56d7ef30279f7d64048519ab901ada336 /uv /usr/local/bin/uv
RUN uv pip install --system --no-cache --exclude-newer 2026-10-28T00:00:00Z workspace-mcp==2.2.0 pysocks \
 && rm /usr/local/bin/uv \
 && useradd -u 10001 -m -d /data mcp && mkdir -p /data/creds && chown -R mcp:mcp /data && chmod 700 /data/creds
USER mcp
WORKDIR /data
ENV HOME=/data \
    WORKSPACE_MCP_CREDENTIALS_DIR=/data/creds \
    GOOGLE_CLIENT_SECRET_PATH=/data/client_secret.json \
    WORKSPACE_MCP_HOST=0.0.0.0 \
    WORKSPACE_MCP_PORT=8000 \
    WORKSPACE_MCP_ALLOWED_HOSTS=gws \
    HTTP_PROXY=http://gate:3128 HTTPS_PROXY=http://gate:3128 http_proxy=http://gate:3128 https_proxy=http://gate:3128 \
    NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1
EXPOSE 8000
# extended: core has no Gmail draft tool. Removed on the server, so not even a direct call from the sandbox reaches
# them: sending mail, sharing files, mail filters (they can forward mail). Calendar deletion cannot be removed alone:
# manage_event creates, changes and deletes.
CMD ["workspace-mcp", "--single-user", "--transport", "streamable-http", "--tool-tier", "extended", "--tools", "gmail", "calendar", "drive", "docs", "sheets", \
     "--disabled-tools", "send_gmail_message", "manage_drive_access", "set_drive_file_permissions", "manage_gmail_filter"]
