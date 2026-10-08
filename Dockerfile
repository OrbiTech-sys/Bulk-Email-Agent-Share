# Pin the official GHCR image to avoid registry throttling and mutable latest tags.
FROM ghcr.io/n8n-io/n8n:2.27.1-95da50e@sha256:cf38a8d28565ab47bfb881ca2ab012e681799580faf0afec8dfeb8646ab67dd6

USER root
WORKDIR /opt/bulk-email-agent
COPY workflows /opt/bulk-email-agent/workflows
COPY data/files/prompts /opt/bulk-email-agent/prompts
COPY start-render.sh /opt/bulk-email-agent/start-render.sh
RUN chmod +x /opt/bulk-email-agent/start-render.sh

ENV N8N_USER_FOLDER=/files/n8n \
    BULK_EMAIL_DATA_DIR=/files \
    N8N_RESTRICT_FILE_ACCESS_TO=/files \
    NODE_FUNCTION_ALLOW_BUILTIN=fs,path,dns,crypto \
    N8N_BLOCK_ENV_ACCESS_IN_NODE=false \
    GENERIC_TIMEZONE=Asia/Karachi \
    TZ=Asia/Karachi

# Stay root: Render mounts the persistent disk at /files owned by root, so the
# non-root "node" user cannot create the data directories there.
ENTRYPOINT ["/opt/bulk-email-agent/start-render.sh"]
