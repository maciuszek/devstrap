FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN mkdir -p /etc/claude-code

COPY --chown=root:root claude-managed-settings.json \
    /etc/claude-code/managed-settings.json

RUN chmod 0444 /etc/claude-code/managed-settings.json
