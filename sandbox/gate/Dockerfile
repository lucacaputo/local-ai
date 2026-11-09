# Sandbox gate image (TASK-042, decision-015): the only way in or out of a sandbox network. No dependencies, run by
# Node's type stripping. Built by scripts\sandbox.ps1 build (context: sandbox\gate).
FROM node:22.19.0-alpine3.22@sha256:d2166de198f26e17e5a442f537754dd616ab069c47cc57b889310a717e0abbf9
WORKDIR /app
RUN echo '{"type":"module"}' > package.json
COPY gate.ts main.ts ./
USER node
EXPOSE 3128
CMD ["node", "main.ts"]
