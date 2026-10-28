#!/usr/bin/env bash
# Étape 2 : sauvegarde complète de l'état initial (lecture seule, ne modifie rien).
# La PREMIÈRE sauvegarde devient la référence utilisée par restore.sh.
# Usage : ./01-backup.sh  (relançable : crée une nouvelle sauvegarde horodatée)
. "$(dirname "$0")/lib.sh"
require_device

B="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$B/shots"
info "Sauvegarde dans $B"

sh_ getprop > "$B/getprop.txt"
sh_ pm list users > "$B/users.txt"
pkg_list -u > "$B/packages-all-incl-uninstalled.txt"
pkg_list    > "$B/packages-installed.txt"
pkg_list -e > "$B/packages-enabled.txt"
pkg_list -d > "$B/packages-disabled.txt"
pkg_list -s > "$B/packages-system.txt"
pkg_list -3 > "$B/packages-thirdparty.txt"
sh_ pm list packages -f -i -u > "$B/packages-details.txt"
sh_ pm list packages --show-versioncode > "$B/packages-versions.txt" 2>/dev/null || true
for ns in global secure system; do sh_ settings list "$ns" > "$B/settings-$ns.txt"; done
current_home > "$B/home-activity.txt"
sh_ cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME > "$B/home-candidates.txt" 2>/dev/null || true
sh_ dumpsys package preferred > "$B/preferred-activities.txt" 2>/dev/null || true
sh_ dumpsys package > "$B/dumpsys-package.txt" 2>/dev/null || true

info "Captures de l'état initial"
go_home;                                         STATE_DIR="$B" shot accueil
sh_ input keyevent KEYCODE_DPAD_DOWN >/dev/null; STATE_DIR="$B" shot accueil-ligne2
sh_ am start -a android.settings.SETTINGS >/dev/null 2>&1 || true
STATE_DIR="$B" shot parametres
sh_ am start -a android.settings.APPLICATION_SETTINGS >/dev/null 2>&1 || true
STATE_DIR="$B" shot applications
go_home

( cd "$B" && find . -type f ! -name MANIFEST.sha256 -exec sh -c 'shasum -a 256 "$1" 2>/dev/null || sha256sum "$1"' _ {} \; > MANIFEST.sha256 )

if [ ! -f "$INITIAL_BACKUP_FILE" ]; then
  echo "$B" > "$INITIAL_BACKUP_FILE"
  info "Sauvegarde de RÉFÉRENCE enregistrée (utilisée par restore.sh)."
else
  info "Sauvegarde de référence existante conservée : $(cat "$INITIAL_BACKUP_FILE")"
fi
echo "Résumé : $(wc -l < "$B/packages-installed.txt" | tr -d ' ') paquets installés, $(wc -l < "$B/packages-disabled.txt" | tr -d ' ') déjà désactivés."
echo "Écran d'accueil actuel : $(cat "$B/home-activity.txt")"
log_action "backup $B"
