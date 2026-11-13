#!/usr/bin/env bash
# Configura Git con chiave SSH: nessuna password a ogni commit/push.
set -euo pipefail
cd "$(dirname "$0")/.."

git config --global user.name "dvdsalviato"
git config --global user.email "dvdsalviato@gmail.com"

KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -C "dvdsalviato@gmail.com" -f "$KEY" -N ""
fi

echo
echo "=== Copia questa chiave pubblica su GitHub ==="
echo "GitHub > Settings > SSH and GPG keys > New SSH key"
echo
cat "$KEY.pub"
echo
read -rp "Premi Invio quando l'hai aggiunta su GitHub... " _

[ -d .git ] || git init -b main
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:dvdsalviato/ukeep.git

ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true
echo "Pronto. Per caricare: git add . && git commit -m 'Primo commit' && git push -u origin main"
