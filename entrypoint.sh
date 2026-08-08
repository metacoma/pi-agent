#!/usr/bin/env bash
#
# pi-agent entrypoint:
#   - prepares the pi agent home (config, kubeconfig)
#   - clones/updates the shitcluster gitops repo
#   - starts `pi` inside a persistent tmux session
#
# With a TTY (kubectl exec -it ... -- /usr/local/bin/entrypoint.sh) it
# attaches to the running session; without a TTY (pod start) it creates a
# detached tmux session and keeps the container alive.

set -euo pipefail

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/pi}"
PI_AGENT_DIR="${PI_AGENT_DIR:-${PI_HOME}/.pi/agent}"
WORKSPACE="${WORKSPACE:-/workspace}"
REPO_DIR="${REPO_DIR:-${WORKSPACE}/shitcluster}"
REPO_URL="${REPO_URL:-https://github.com/metacoma/shitcluster2.git}"
REPO_BRANCH="${REPO_BRANCH:-master}"
PI_SESSION="${PI_SESSION:-pi}"

PI_PROVIDER="${PI_PROVIDER:-litellm}"
PI_MODEL="${PI_MODEL:-openai/deepseek-v4-flash-q3}"

export HOME="${PI_HOME}"
export TERM="${TERM:-xterm-256color}"
# UTF-8 locale: required for Cyrillic input inside tmux/pi
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-C.UTF-8}"
export PI_CODING_AGENT_DIR="${PI_AGENT_DIR}"
export KUBECONFIG="${KUBECONFIG:-${PI_HOME}/.kube/config}"

# ---------------------------------------------------------------------------
# 1. Prepare home directory layout
# ---------------------------------------------------------------------------
mkdir -p "${PI_AGENT_DIR}" "${PI_HOME}/.kube" "${PI_HOME}/.ssh" "${WORKSPACE}"
if [ "$(id -un)" = "root" ]; then
  chown -R "${PI_USER}:${PI_USER}" "${PI_HOME}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 2. Generate in-cluster kubeconfig from the ServiceAccount token (preferred)
#    Falls back to a mounted kubeconfig Secret if no SA token is present.
# ---------------------------------------------------------------------------
SA_DIR=/var/run/secrets/kubernetes.io/serviceaccount
if [ -f "${SA_DIR}/token" ] && [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
  echo "[pi-agent] generating in-cluster kubeconfig from ServiceAccount ${SA_DIR}/token"
  cat > "${KUBECONFIG}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${SA_DIR}/ca.crt
    server: https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
  name: in-cluster
contexts:
- context:
    cluster: in-cluster
    user: pi-agent
  name: in-cluster
current-context: in-cluster
users:
- name: pi-agent
  user:
    tokenFile: ${SA_DIR}/token
EOF
  chmod 600 "${KUBECONFIG}"
fi

# ---------------------------------------------------------------------------
# 3. Clone / update the gitops repository
# ---------------------------------------------------------------------------
if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "[pi-agent] cloning ${REPO_URL} -> ${REPO_DIR}"
  git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${REPO_DIR}" \
    || echo "[pi-agent] clone failed, continuing with empty workspace"
else
  echo "[pi-agent] updating ${REPO_DIR}"
  git -C "${REPO_DIR}" pull --ff-only --quiet || true
fi

# ---------------------------------------------------------------------------
# 4. Validate config was injected
# ---------------------------------------------------------------------------
for f in settings.json mcp.json models.json; do
  if [ ! -f "${PI_AGENT_DIR}/${f}" ]; then
    echo "[pi-agent] WARNING: ${PI_AGENT_DIR}/${f} not found (config not injected?)"
  fi
done
[ -f "${KUBECONFIG}" ] || echo "[pi-agent] WARNING: ${KUBECONFIG} not found"

# ---------------------------------------------------------------------------
# 5. Start pi in tmux
# ---------------------------------------------------------------------------
cd "${REPO_DIR}"

if [ -t 0 ]; then
  # interactive: attach to the persistent session (create if missing)
  exec tmux new-session -A -s "${PI_SESSION}" -- \
    pi --provider "${PI_PROVIDER}" --model "${PI_MODEL}"
fi

# non-interactive (pod start): create detached session, keep container alive
echo "[pi-agent] starting pi (provider=${PI_PROVIDER}, model=${PI_MODEL}) in tmux session '${PI_SESSION}'"
tmux new-session -d -s "${PI_SESSION}" \
  "cd ${REPO_DIR} && exec pi --provider ${PI_PROVIDER} --model ${PI_MODEL}"

echo "[pi-agent] ready. Attach: kubectl exec -it <pod> -- tmux attach -t ${PI_SESSION}"
exec tail -f /dev/null
