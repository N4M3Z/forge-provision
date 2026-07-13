# claude-box-redact: claude-box (VIRT-0002) with an in-VM PII/secret redaction
# proxy (forge-redact: mitmproxy + Microsoft Presidio). Claude routes through the
# proxy on loopback; only redacted traffic egresses. See VIRT-0003.
#
# Disposable mode only: do NOT mount a named volume at /home/node, it would shadow
# the baked policy, the sandbox settings, the public key, and the proxy CA. `redact
# run` mounts only /seed (read-only), /capture, and /work.
#
# Built by `redact build` (scripts/sandbox/claude-box/redact), which uses this
# directory as the build context. The tracked files here (redact-policy.yaml,
# managed-settings.json, redact-entry) are COPYed by name; the build adds the two
# inputs that are not tracked -- forge_redact.whl (the wheel from ../forge-redact)
# and pubkey.asc (the operator GPG public key) -- and removes them afterward.
#
# Build the base image (claude-box) first. The Presidio + spaCy model layer is
# large; bump the builder VM once: container builder start -m 4g.

FROM claude-box

ARG GPG_RECIPIENT

ENV HOME=/home/node

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip gnupg curl \
    && rm -rf /var/lib/apt/lists/*

COPY forge_redact.whl /tmp/forge_redact.whl
RUN pip3 install --break-system-packages --no-cache-dir /tmp/forge_redact.whl \
    && rm /tmp/forge_redact.whl

COPY redact-policy.yaml /home/node/.config/forge/presidio.yaml
RUN sed -i "s|^vault_gpg_recipient:.*|vault_gpg_recipient: \"${GPG_RECIPIENT}\"|" \
        /home/node/.config/forge/presidio.yaml

COPY managed-settings.json /etc/claude-code/managed-settings.json
COPY pubkey.asc /tmp/pubkey.asc
COPY redact-entry /usr/local/bin/redact-entry
RUN chmod +x /usr/local/bin/redact-entry \
    && mkdir -p /seed /capture /home/node/.config/forge \
    && chown -R node:node /home/node/.config /capture

USER node

# Import the public key (touchless encrypt) and fail the build if the configured
# recipient does not resolve, so a misconfigured box never reaches runtime.
RUN gpg --import /tmp/pubkey.asc \
    && gpg --list-keys "${GPG_RECIPIENT}" >/dev/null

ENTRYPOINT ["redact-entry"]
