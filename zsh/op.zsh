# core/zsh/op.zsh
# 1Password CLI helpers — portable across machines. The macOS SSH-agent socket
# path is OS-specific and lives in os/macos.zsh, NOT here. If `op` isn't
# installed, this file does nothing.
# Docs: https://developer.1password.com/docs/cli

command -v op >/dev/null 2>&1 || return 0

# opsecret — fetch a secret by vault/item/field path
# Usage: opsecret "Personal/AWS/access_key_id"
opsecret() {
  if [[ -z "$1" ]]; then
    echo "Usage: opsecret <vault>/<item>/<field>"
    return 1
  fi
  op read "op://$1"
}

# openv — run a command with secrets from a .env.op template
# Usage: openv .env.op npm run dev   (.env.op format: KEY=op://vault/item/field)
openv() {
  if [[ -z "$1" ]]; then
    echo "Usage: openv <env-template-file> <command...>"
    return 1
  fi
  op run --env-file="$1" -- "${@:2}"
}

# optoken — copy a TOTP code to the clipboard via Core's cross-OS `clip`
# Usage: optoken "Personal/GitHub"
optoken() {
  if [[ -z "$1" ]]; then
    echo "Usage: optoken <vault>/<item>"
    return 1
  fi
  op item get "$1" --otp | clip && echo "✓ TOTP copied to clipboard"
}

# opssh — list SSH keys stored in 1Password
opssh() {
  op item list --categories "SSH Key" --format table
}
