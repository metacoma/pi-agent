# pi-agent

Pi coding agent container image for the shitcluster homelab. Ships the [Pi](https://pi.dev) coding agent plus a full Kubernetes/GitOps ops toolkit matching the [shitcluster skills](https://github.com/metacoma/shitcluster2).

## Image

`ghcr.io/metacoma/pi-agent:latest` — built automatically on every push to `master`/`main` via GitHub Actions.

## Included tooling

| Category | Tools |
|---|---|
| Kubernetes | `kubectl`, `helm`, `argocd` |
| GitOps | `kcl`, `vals`, `sops`, `yq` |
| HashiCorp | `vault` CLI |
| Network diagnostics | `nmap`, `nc`, `dig`/`nslookup`, `ping`, `traceroute`, `mtr`, `whois`, `ip`, `iptables`, `nftables` |
| SSH | `ssh`, `scp`, `ssh-keygen`, `sshpass`, `expect` |
| Scripting | `git`, `make`, `python3`/`pip`, `jq`, `curl`, `wget`, `tmux`, `vim`, `ripgrep`, docker CLI |
| LLM | Pi coding agent (`pi`), `pi-mcp-adapter`, `pi-ai` |
| Runtime | Node.js LTS 24 |

Base: Ubuntu 26.04 LTS (resolute).

## Usage in cluster

Deployed by ArgoCD into namespace `ai`. Configuration is injected at deploy time:

- **ConfigMap** `pi-agent-config` → `settings.json`, `mcp.json`, `auth.json` (see `config/`)
- **Secret** (from Vault via vals) → `models.json` (contains the litellm API key) and the cluster `kubeconfig`

The entrypoint clones/updates the gitops repo into `/workspace/shitcluster` and starts `pi` inside a tmux session. Attach to the agent:

```bash
kubectl exec -it -n ai deploy/pi-agent -- tmux attach -t pi
```

## Build locally

```bash
docker build -t pi-agent:local .
```
