FROM docker.n8n.io/n8nio/n8n:latest

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

USER node
ENTRYPOINT ["/opt/bulk-email-agent/start-render.sh"]
