# syntax=docker/dockerfile:1
#
# pi-agent — Pi coding agent + shitcluster ops toolkit
# Base: latest Ubuntu LTS (26.04 "resolute")

FROM ubuntu:26.04

ARG KUBECTL_VERSION=v1.36.3
ARG HELM_VERSION=v4.2.3
ARG KCL_VERSION=v0.11.2
ARG SOPS_VERSION=3.13.3
ARG VAULT_VERSION=2.0.4
ARG ARGOCD_VERSION=v3.5.0
ARG VALS_VERSION=0.45.0
ARG YQ_VERSION=v4.53.3
ARG NODE_VERSION=v24.19.0
ARG PI_VERSION=0.83.0
ARG PI_MCP_ADAPTER_VERSION=2.15.0
ARG PI_AI_VERSION=0.0.1

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PI_USER=pi \
    PI_HOME=/home/pi

# ---------------------------------------------------------------------------
# 1. System packages — every CLI used by the shitcluster skills
#    (ssh-connect, vpn-nl-connect, dns-update-from-pod, management-pod,
#     longhorn-diagnose, kcl-validate, argocd-deploy, vault-secret, ...)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    git \
    make \
    tmux \
    vim \
    gnupg \
    unzip \
    xz-utils \
    ripgrep \
    # network diagnostics
    nmap \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    traceroute \
    mtr \
    whois \
    iproute2 \
    iptables \
    nftables \
    openssh-client \
    sshpass \
    # scripting / automation
    jq \
    python3 \
    python3-pip \
    python3-venv \
    expect \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Node.js LTS (pi requires >= 22.19)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1 \
    && node --version && npm --version

# ---------------------------------------------------------------------------
# 3. Kubernetes & GitOps CLIs
# ---------------------------------------------------------------------------
# kubectl
RUN curl -fsSL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    | tar -xz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64

# kcl (version matches the ArgoCD CMP image ghcr.io/metacoma/kcl-vals)
RUN curl -fsSL https://github.com/kcl-lang/kcl/releases/download/${KCL_VERSION}/kclvm-${KCL_VERSION}-linux-amd64.tar.gz \
    | tar -xz -C /opt \
    && ln -sf /opt/kclvm/bin/kclvm_cli /usr/local/bin/kcl \
    && ln -sf /opt/kclvm/bin/kcl-language-server /usr/local/bin/kcl-lsp \
    && kcl version || true

# argocd CLI
RUN curl -fsSL https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64 \
    -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd

# sops (secrets)
RUN curl -fsSL https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64 \
    -o /usr/local/bin/sops \
    && chmod +x /usr/local/bin/sops

# vault CLI
RUN curl -fsSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
    -o /tmp/vault.zip \
    && unzip -o /tmp/vault.zip -d /usr/local/bin \
    && rm /tmp/vault.zip

# vals (ref+vault:// resolution)
RUN curl -fsSL https://github.com/helmfile/vals/releases/download/v${VALS_VERSION}/vals_${VALS_VERSION}_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin vals \
    && chmod +x /usr/local/bin/vals

# yq
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# docker CLI (used by the kcl-validate skill; needs a daemon socket)
RUN apt-get update && apt-get install -y --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4. Python tooling used by skills (ansible for the ansible/ tree)
# ---------------------------------------------------------------------------
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    ansible \
    pyyaml

# ---------------------------------------------------------------------------
# 5. Pi coding agent
# ---------------------------------------------------------------------------
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}

# dedicated non-root user
RUN useradd -m -s /bin/bash ${PI_USER} \
    && mkdir -p ${PI_HOME}/.pi/agent \
    && chown -R ${PI_USER}:${PI_USER} ${PI_HOME}

# pre-install pi packages (pi-mcp-adapter, pi-ai) into the agent dir
USER ${PI_USER}
ENV HOME=${PI_HOME}
RUN pi install npm:pi-mcp-adapter@${PI_MCP_ADAPTER_VERSION} \
    && pi install npm:pi-ai@${PI_AI_VERSION} \
    && pi list || true

USER root
RUN chmod +x /usr/local/bin/*

# ---------------------------------------------------------------------------
# 6. Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
