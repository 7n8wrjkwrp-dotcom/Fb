#!/usr/bin/env bash
# Fonctions communes. Compatible bash 3.2 (macOS), Linux et Git Bash/WSL (Windows).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="${ADB:-adb}"
STATE_DIR="${STATE_DIR:-$ROOT/state}"
mkdir -p "$STATE_DIR"
DEVICE_FILE="$STATE_DIR/device"
DEVICE="${DEVICE:-}"
if [ -z "$DEVICE" ] && [ -f "$DEVICE_FILE" ]; then DEVICE="$(cat "$DEVICE_FILE")"; fi
INITIAL_BACKUP_FILE="$STATE_DIR/initial-backup"
ACTIONS_LOG="$STATE_DIR/actions.log"
SETTINGS_LOG="$STATE_DIR/settings-changed.tsv"   # ns<TAB>clé<TAB>valeur d'origine
PROJECTIVY_PKG="com.spocky.projengmenu"
STOCK_LAUNCHER_PKG="com.google.android.tvlauncher"

# Paquets qu'aucun script ne désactivera jamais (stabilité / démarrage / télécommande).
CRITICAL_REGEX='^(android|com\.android\.vending|com\.android\.(systemui|settings|shell|bluetooth|phone|inputdevices|keychain|externalstorage|documentsui|se|permissioncontroller|packageinstaller|tv\.settings|server\..*|providers\..*|location\..*|networkstack.*|wifi.*|nfc|media.*|externalstorage)|com\.google\.android\.(gms|gsf|webview|tvlauncher|packageinstaller|permissioncontroller|configupdater|onetimeinitializer|tungsten\..*|tv\.remote\.service|tv\.frameworkpackagestubs|ext\..*|inputmethod\..*|modulemetadata|networkstack.*)|com\.(droidlogic|amlogic|mediatek)\..*)$'

die()  { echo "ERREUR : $*" >&2; exit 1; }
info() { echo "==> $*"; }
log_action() { echo "$(date '+%Y-%m-%d %H:%M:%S')	$*" >> "$ACTIONS_LOG"; }

adb_() { if [ -n "$DEVICE" ]; then "$ADB" -s "$DEVICE" "$@"; else "$ADB" "$@"; fi; }
sh_()  { adb_ shell "$@" </dev/null | tr -d '\r'; }

require_device() {
  command -v "$ADB" >/dev/null 2>&1 || die "adb introuvable. Lance ./00-connect.sh pour les instructions d'installation."
  [ "$(adb_ get-state 2>/dev/null | tr -d '\r')" = "device" ] || die "Clé non connectée (DEVICE='${DEVICE}'). Lance ./00-connect.sh"
}

require_initial_backup() {
  [ -f "$INITIAL_BACKUP_FILE" ] && [ -d "$(cat "$INITIAL_BACKUP_FILE")" ] \
    || die "Pas de sauvegarde initiale. Lance d'abord ./01-backup.sh"
  cat "$INITIAL_BACKUP_FILE"
}

is_critical() { echo "$1" | grep -Eq "$CRITICAL_REGEX"; }

# pkg_list [flags pm] -> noms de paquets triés
pkg_list() { sh_ pm list packages "$@" | sed -n 's/^package://p' | sort -u; }

# Paquet installé pour l'utilisateur 0 ?
pkg_installed() { pkg_list | grep -Fxq "$1"; }
pkg_disabled()  { pkg_list -d | grep -Fxq "$1"; }

# Composant de l'écran d'accueil actuel (vide si aucun par défaut)
current_home() {
  sh_ cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
    | tail -n 1 | grep '/' || true
}

# shot <nom> : capture de l'écran de la télé dans state/shots/
shot() {
  mkdir -p "$STATE_DIR/shots"
  local f="$STATE_DIR/shots/$(date +%Y%m%d-%H%M%S)-$1.png"
  sh_ input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  sleep "${SHOT_DELAY:-2}"
  adb_ exec-out screencap -p > "$f" </dev/null
  if [ -s "$f" ]; then echo "   📸 Capture : $f"; else echo "   ⚠️  Capture vide (contenu protégé DRM ou écran éteint) : $f"; fi
}

go_home() { sh_ input keyevent KEYCODE_HOME >/dev/null; }

confirm() { # confirm "question" -> 0 si oui (défaut : non)
  local a; read -r -p "$1 [o/N] " a </dev/tty 2>/dev/null || a=""
  case "$a" in o|O|oui|OUI|y|Y|yes) return 0;; *) return 1;; esac
}

# settings_put_tracked ns clé valeur : modifie un réglage en mémorisant sa valeur d'origine
settings_put_tracked() {
  local ns="$1" key="$2" val="$3" orig
  if ! grep -q "^$ns	$key	" "$SETTINGS_LOG" 2>/dev/null; then
    orig="$(sh_ settings get "$ns" "$key")"
    printf '%s\t%s\t%s\n' "$ns" "$key" "$orig" >> "$SETTINGS_LOG"
  fi
  sh_ settings put "$ns" "$key" "$val" >/dev/null
  log_action "settings put $ns $key $val"
}
