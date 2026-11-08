# Fixture websites for the agent bench (TASK-040). Built from bench\agent\fixtures:
#   docker build -t local-ai/agent-fixtures bench\agent\fixtures
# Run by the runner on the agent-bench network, with one network alias per site (sites\pages.ts HOSTS).
FROM node:22.19.0-alpine3.22@sha256:d2166de198f26e17e5a442f537754dd616ab069c47cc57b889310a717e0abbf9
WORKDIR /app
RUN echo '{"type":"module"}' > package.json
COPY web-data.ts ./
COPY sites/pages.ts sites/server.ts ./sites/
USER node
ENV PORT=80 ADMIN_PORT=8081
EXPOSE 80 8081
CMD ["node", "sites/server.ts"]
