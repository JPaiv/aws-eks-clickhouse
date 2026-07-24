# syntax=docker/dockerfile:1

# ---------- Stage 1/3: Tool builder ----------
# Debian instead of Alpine: AWS CLI v2 is a glibc/PyInstaller build, and GNU
# unzip handles its archive correctly (busybox unzip mishandles some zip
# features).
FROM debian:bookworm-slim AS tool-builder

ARG OPENTOFU_VERSION=1.12.5
ARG TERRAMATE_VERSION=0.17.1
ARG TERRAFORM_DOCS_VERSION=0.20.0
ARG TFLINT_VERSION=0.64.0
ARG TRIVY_VERSION=0.72.0
ARG TASK_VERSION=3.52.0
ARG CLOUD_NUKE_VERSION=0.41.0
ARG AWS_CLI_VERSION=2.35.21
ARG KUBECTL_VERSION=1.36.2
ARG HELM_VERSION=4.2.3
ARG ARGOCD_VERSION=3.4.5
ARG K9S_VERSION=0.51.0
ARG GH_VERSION=2.96.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# INFRASTRUCTURE-AS-CODE
# -----------------------------------------------------------------------------

# OpenTofu — the only executor. The Terraform CLI is deliberately absent:
# `tofu fmt`/`tofu validate` cover formatting and validation, and every other
# tool here (terramate, tflint, terraform-docs, trivy) parses HCL itself
# rather than shelling out to a terraform binary.
RUN curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.tar.gz" -o tofu.tar.gz \
    && tar -xzf tofu.tar.gz -C /usr/local/bin tofu \
    && rm tofu.tar.gz

# Terramate — stack orchestration + code generation (replaces Terragrunt).
# terramate-ls is the language server the VS Code extension drives; the tarball
# also ships cosign.pub, which is deliberately not extracted.
RUN curl -fsSL "https://github.com/terramate-io/terramate/releases/download/v${TERRAMATE_VERSION}/terramate_${TERRAMATE_VERSION}_linux_x86_64.tar.gz" -o terramate.tar.gz \
    && tar -xzf terramate.tar.gz -C /usr/local/bin terramate terramate-ls \
    && rm terramate.tar.gz

# Terraform-docs — module documentation generator (HCL parser, no CLI needed)
RUN curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz" -o terraform-docs.tar.gz \
    && tar -xzf terraform-docs.tar.gz -C /usr/local/bin terraform-docs \
    && rm terraform-docs.tar.gz

# TFLint — HCL linter, understands OpenTofu sources natively
RUN curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" -o tflint.zip \
    && unzip -q tflint.zip tflint -d /usr/local/bin \
    && rm tflint.zip

# Trivy — replaces tfsec, which Aqua put into maintenance mode and folded into
# trivy. `trivy config` runs the same misconfiguration checks, plus image and
# Kubernetes-manifest scanning that tfsec never had.
RUN curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -o trivy.tar.gz \
    && tar -xzf trivy.tar.gz -C /usr/local/bin trivy \
    && rm trivy.tar.gz

# -----------------------------------------------------------------------------
# TASK RUNNER
# -----------------------------------------------------------------------------

# go-task — the single entrypoint for every workflow in this repo (Taskfile.yml)
RUN curl -fsSL "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_amd64.tar.gz" -o task.tar.gz \
    && tar -xzf task.tar.gz -C /usr/local/bin task \
    && rm task.tar.gz

# -----------------------------------------------------------------------------
# CLOUD
# -----------------------------------------------------------------------------

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o awscliv2.zip \
    && unzip -q awscliv2.zip \
    && ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli \
    && rm -rf awscliv2.zip aws

# Cloud-nuke — teardown safety net for a demo account
RUN curl -fsSL "https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_linux_amd64" -o /usr/local/bin/cloud-nuke \
    && chmod 755 /usr/local/bin/cloud-nuke

# -----------------------------------------------------------------------------
# KUBERNETES
# -----------------------------------------------------------------------------

# kubectl — eksctl is intentionally absent; OpenTofu creates the cluster and
# `aws eks update-kubeconfig` writes the kubeconfig.
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod 755 /usr/local/bin/kubectl

# Helm — installs the ClickHouse operator and the ACK controllers
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" -o helm.tar.gz \
    && tar -xzf helm.tar.gz -C /usr/local/bin --strip-components=1 linux-amd64/helm \
    && rm helm.tar.gz

# Argo CD CLI — app sync/status and `argocd app diff` against the cluster
RUN curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64" -o /usr/local/bin/argocd \
    && chmod 755 /usr/local/bin/argocd

# k9s — terminal UI over the kubeconfig contexts kubectl already uses
RUN curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o k9s.tar.gz \
    && tar -xzf k9s.tar.gz -C /usr/local/bin k9s \
    && rm k9s.tar.gz

# -----------------------------------------------------------------------------
# SOURCE CONTROL
# -----------------------------------------------------------------------------

# GitHub CLI — PRs, release-please release PRs, and CI run inspection.
# The tarball nests everything under gh_<version>_linux_amd64/, and ships man
# pages and completions that are not extracted.
RUN curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o gh.tar.gz \
    && tar -xzf gh.tar.gz -C /usr/local/bin --strip-components=2 "gh_${GH_VERSION}_linux_amd64/bin/gh" \
    && rm gh.tar.gz


# ---------- Stage 2/3: Node ----------
FROM node:24.8.0 AS node-builder

RUN npm install -g \
    @anthropic-ai/claude-code \
    pnpm \
    tsx \
    typescript


# ---------- Stage 3/3: Runtime devcontainer ----------
# Pinned: the floating :ubuntu tag now resolves to 26.04 "resolute", which the
# docker-in-docker feature can't install on with its default moby=true
# (Microsoft publishes no moby packages for resolute). Move to 26.04
# deliberately later, together with '"moby": false' in the feature options.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS runtime

# Tool binaries + the aws entrypoint symlink.
# No --chmod: plain COPY preserves the correct 0755 bits set in the builder.
COPY --from=tool-builder /usr/local/bin /usr/local/bin

# AWS CLI install tree (the symlinks in /usr/local/bin resolve here)
COPY --from=tool-builder /usr/local/aws-cli /usr/local/aws-cli

# Node — bin symlinks resolve into ../lib/node_modules, so both dirs are needed
COPY --from=node-builder /usr/local/bin /usr/local/bin
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules

# Devcontainer post-start script
COPY --chmod=755 post-start.sh /usr/local/bin/post-start

ENV TZ="Europe/Helsinki"

# DEPENDENCIES
# - jq: JSON wrangling for `aws ... --output json` in Taskfile targets
# - python3 toolchain: ad-hoc scripting; the AWS CLI ships its own runtime
# - python3-yaml: PyYAML for validating the Argo CD / ACK manifests under apps/.
#   Installed from the distro, not pip: Ubuntu 24.04's system Python is
#   PEP-668 externally-managed, so `pip install` would need --break-system-packages.
# Post-copy fixup: drop the node image's yarn symlinks, whose /opt targets
# weren't copied (dangling otherwise; pnpm is the package manager here)
RUN apt-get update && apt-get install -y --no-install-recommends \
        jq \
        python3 \
        python3-pip \
        python3-venv \
        python3-yaml \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/local/bin/yarn /usr/local/bin/yarnpkg
