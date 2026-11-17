#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# LCNC-Cyclo – Installation für Tester (Debian 13, auch unter WSL2)
#
# Das Repo ist privat. Zugang gibt es über einen eigenen SSH-Schlüssel, den der
# Projektverantwortliche bei GitHub als "Deploy Key" (nur lesen) freischaltet.
# Ein eigenes GitHub-Konto ist dafür nicht nötig.
#
# Ablauf:
#   1. Skript starten:  bash lcnc-cyclo-tester.sh
#   2. Beim ersten Mal zeigt es einen Schlüssel an (eine Zeile, beginnt mit
#      ssh-ed25519). Diese Zeile an den Projektverantwortlichen schicken.
#   3. Nach der Freischaltung das Skript erneut starten (oder Enter drücken,
#      wenn es noch wartet). Ist das Repo erreichbar, wird alles geholt,
#      LinuxCNC mit LCNC-Cyclo gebaut und die Startbefehle angelegt.
#
# Später aktualisieren:  cyclo-update
#
# Optionen:
#   --check   nur prüfen, ob der Zugang klappt (nichts installieren)
#   --tests   nach dem Bauen die Tests laufen lassen (dauert länger)
# Zielordner änderbar:  CYCLO_DIR=~/cnc/lcnc-cyclo bash lcnc-cyclo-tester.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_PATH="Slayer1000/lcnc-cyclo.git"
BRANCH="master"
HOST_ALIAS="github-lcnc-cyclo"
KEY="$HOME/.ssh/lcnc_cyclo_ed25519"
REPO_URL="git@$HOST_ALIAS:$REPO_PATH"
CYCLO_DIR="${CYCLO_DIR:-$HOME/lcnc-cyclo}"
ONLY_CHECK=0
TEST_OPT="--no-tests"
for a in "$@"; do
  case "$a" in
    --check) ONLY_CHECK=1 ;;
    --tests) TEST_OPT="" ;;
    -h|--help) sed -n 2,23p "$0"; exit 0 ;;
    *) echo "Unbekannte Option: $a" >&2; exit 1 ;;
  esac
done

info() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m[X] %s\033[0m\n' "$*" >&2; exit 1; }

# --- 0. Vorprüfungen -------------------------------------------------------
[ "$(id -u)" -ne 0 ] || fail "Bitte als normaler Benutzer starten, nicht als root (sudo wird intern benutzt)."
command -v sudo >/dev/null || fail "sudo fehlt. Als root: apt install sudo && usermod -aG sudo $USER, danach neu anmelden."
. /etc/os-release
IS_WSL=0
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
echo "System: ${PRETTY_NAME:-unbekannt}$([ $IS_WSL -eq 1 ] && echo ' (WSL)')"

# git und ssh werden schon für die Zugangsprüfung gebraucht
if ! command -v git >/dev/null || ! command -v ssh >/dev/null || ! command -v ssh-keygen >/dev/null; then
  info "git und ssh installieren"
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends git openssh-client ca-certificates
fi

# --- 1. Eigener Schlüssel nur für LCNC-Cyclo -------------------------------
# Getrennt von evtl. vorhandenen Schlüsseln, weil GitHub einen Deploy Key nur
# einmal vergibt und ein Schlüssel aus einem GitHub-Konto dafür nicht geht.
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if [ ! -f "$KEY" ]; then
  info "Zugangsschlüssel erzeugen"
  ssh-keygen -q -t ed25519 -N "" -C "lcnc-cyclo-tester $USER@$(hostname)" -f "$KEY"
fi
# Host-Eintrag "$HOST_ALIAS" in ~/.ssh/config (neu) schreiben. Port 22 ist Standard;
# in manchen Netzen gesperrt, dann über ssh.github.com:443 (bietet GitHub dafür an).
write_host() {   # write_host <HostName> <Port>
  local cfg="$HOME/.ssh/config"
  touch "$cfg"
  # alten Block (Host-Zeile bis Leerzeile) entfernen
  awk -v h="Host $HOST_ALIAS" '$0==h{skip=1;next} skip&&/^[[:space:]]*$/{skip=0;next} !skip' "$cfg" > "$cfg.tmp"
  mv "$cfg.tmp" "$cfg"
  cat >> "$cfg" <<EOF

Host $HOST_ALIAS
    HostName $1
    Port $2
    User git
    IdentityFile $KEY
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new

EOF
  chmod 600 "$cfg"
}
grep -q "^Host $HOST_ALIAS\$" "$HOME/.ssh/config" 2>/dev/null || write_host github.com 22

# --- 2. Zugang prüfen ------------------------------------------------------
repo_ok() {
  GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15" \
    git ls-remote --heads "$REPO_URL" "$BRANCH" >/dev/null 2>&1
}
net_ok() {
  # Antwortet GitHub überhaupt? (Fehlermeldung "Permission denied" = erreichbar, aber nicht freigeschaltet)
  local out
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 -T "$HOST_ALIAS" 2>&1 || true)"
  [[ "$out" == *"Permission denied"* || "$out" == *"successfully authenticated"* || "$out" == *"Hi "* ]]
}

info "Zugang zum Repo prüfen"
if ! repo_ok && ! net_ok; then
  echo "Port 22 nicht erreichbar, versuche SSH über Port 443."
  write_host ssh.github.com 443
fi
if repo_ok; then
  echo "Zugang ok."
else
  if ! net_ok; then
    warn "GitHub ist nicht erreichbar (Internet, Firewall oder Proxy prüfen)."
    ssh -o BatchMode=yes -o ConnectTimeout=15 -T "$HOST_ALIAS" 2>&1 | tail -2 || true
    exit 1
  fi
  echo
  echo "Noch kein Zugang. Bitte diese Zeile an den Projektverantwortlichen schicken:"
  echo "-----------------------------------------------------------------"
  cat "$KEY.pub"
  echo "-----------------------------------------------------------------"
  if [ $IS_WSL -eq 1 ] && command -v clip.exe >/dev/null; then
    clip.exe < "$KEY.pub" && echo "(Liegt schon in der Windows-Zwischenablage, einfach mit Strg+V einfügen.)"
  fi
  echo
  echo "Nach der Freischaltung hier Enter drücken. Oder mit q beenden und das Skript"
  echo "später einfach noch einmal starten, der Schlüssel bleibt erhalten."
  while true; do
    read -rp "Enter = erneut prüfen, q = beenden: " ans
    [[ "$ans" =~ ^[qQ]$ ]] && exit 0
    if repo_ok; then echo "Zugang ok."; break; fi
    warn "Noch nicht freigeschaltet."
  done
fi
[ $ONLY_CHECK -eq 1 ] && { echo "Nur Prüfung (--check), fertig."; exit 0; }

# --- 3. Repo holen ---------------------------------------------------------
if [ -d "$CYCLO_DIR/.git" ]; then
  info "Vorhandenen Stand in $CYCLO_DIR aktualisieren"
  git -C "$CYCLO_DIR" remote set-url origin "$REPO_URL"
  git -C "$CYCLO_DIR" pull --ff-only origin "$BRANCH" \
    || warn "Aktualisieren nicht möglich (lokale Änderungen?) – baue den vorhandenen Stand."
else
  [ -e "$CYCLO_DIR" ] && fail "$CYCLO_DIR existiert schon, ist aber kein Git-Checkout. Bitte umbenennen oder CYCLO_DIR setzen."
  info "Repo nach $CYCLO_DIR holen (nur aktueller Stand, ein paar Minuten)"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CYCLO_DIR"
fi

# --- 4. Installation wie für Entwickler, aber mit Tester-Zugang -------------
INSTALL="$CYCLO_DIR/cyclo/install/install-debian13.sh"
[ -f "$INSTALL" ] || fail "Installationsskript fehlt: $INSTALL"
info "Abhängigkeiten installieren und LinuxCNC mit LCNC-Cyclo bauen"
CYCLO_DIR="$CYCLO_DIR" CYCLO_REPO_URL="$REPO_URL" exec bash "$INSTALL" $TEST_OPT
