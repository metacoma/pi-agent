# Global agent rules (pi-agent container)

These rules apply to every pi session running in this container, regardless of
the project. They are loaded from `~/.pi/agent/AGENTS.md`.

## Secret handling — the Telegram bridge mirrors everything you write

Every assistant reply, tool call, and thinking block is **mirrored to the
Telegram bot chat** by the `pi-telegram-plus` extension. Treat everything you
output as public to anyone with access to that chat:

- **NEVER paste raw secrets (passwords, tokens, API keys, private keys,
  decrypted SOPS/Vault values) into your replies.** Replace every secret with
  a redacted placeholder:
  - password/token values → `***`
  - private keys → `[redacted key]`
  - decrypted values you were asked to show → show only the first/last few
    chars, e.g. `abcd…wxyz`
- When you need to reference a secret (e.g. "run `make argocd_password`"),
  describe the command instead of pasting the resulting value.
- If a tool returns secret material (e.g. `sops -d`, `vault kv get`, reading
  `.env`), do NOT copy it into your reply text — summarize what it contains.
- Do not attach secret files via `tg_attach` unless the user explicitly asked
  for that exact file. `tg_attach` already blocks `/etc` and `~/.ssh`, but
  files like `secrets/*.sops.yaml`, `.env`, and kubeconfigs can still leak.
- The TUI/Telegram mirror cannot be disabled per-message: assume every
  assistant message is visible in Telegram.

## General container hygiene

- `~/.pi/agent/tg.json` contains the bot token and `lastUpdateId` — never
  print its contents.
- Session JSONL under `~/.pi/agent/sessions/` may contain secret material —
  never attach or `cat` full sessions to Telegram; export with redaction.
