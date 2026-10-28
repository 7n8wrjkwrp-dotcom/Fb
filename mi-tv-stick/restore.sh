#!/usr/bin/env bash
# Restauration : remet la clé dans l'état de la sauvegarde de référence (state/initial-backup).
#  • réactive tout paquet désactivé depuis (pm enable) et redésactive ce qui l'était au départ
#  • réinstalle pour l'utilisateur tout paquet système retiré (cmd package install-existing)
#  • remet les réglages modifiés par ces scripts à leur valeur d'origine
#  • remet l'écran d'accueil d'origine
# Usage : ./restore.sh [--dry-run] [--remove-added-apps] [--remove-wallpapers]
#   --remove-added-apps : désinstalle les applis ajoutées depuis la sauvegarde (ex. Projectivy), avec confirmation
. "$(dirname "$0")/lib.sh"
require_device
B="$(require_initial_backup)"

DRY=0; RM_APPS=0; RM_WP=0
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1;; --remove-added-apps) RM_APPS=1;; --remove-wallpapers) RM_WP=1;;
  *) die "Option inconnue : $1";; esac; shift; done
run() { if [ "$DRY" = 1 ]; then echo "  (simulation) $*"; else echo "  → $*"; sh_ "$@" >/dev/null; log_action "restore: $*"; fi; }

info "Restauration depuis $B"
NOW_DIS="$STATE_DIR/.now-disabled"; NOW_INST="$STATE_DIR/.now-installed"
pkg_list -d > "$NOW_DIS"; pkg_list > "$NOW_INST"

info "1/4 Paquets"
comm -23 "$B/packages-installed.txt" "$NOW_INST" | while read -r p; do run cmd package install-existing "$p"; done
pkg_list -d > "$NOW_DIS"
comm -23 "$NOW_DIS" "$B/packages-disabled.txt" | while read -r p; do run pm enable --user 0 "$p"; done
comm -13 "$NOW_DIS" "$B/packages-disabled.txt" | while read -r p; do
  if pkg_installed "$p"; then run pm disable-user --user 0 "$p"; fi; done

info "2/4 Réglages"
if [ -f "$SETTINGS_LOG" ]; then
  while IFS='	' read -r ns key val; do
    if [ "$val" = "null" ] || [ -z "$val" ]; then run settings delete "$ns" "$key"
    else run settings put "$ns" "$key" "$val"; fi
  done < "$SETTINGS_LOG"
  [ "$DRY" = 1 ] || mv "$SETTINGS_LOG" "$SETTINGS_LOG.restored-$(date +%Y%m%d-%H%M%S)"
fi

info "3/4 Écran d'accueil"
ORIG_HOME="$(cat "$B/home-activity.txt")"
if [ -n "$ORIG_HOME" ] && [ "$(current_home)" != "$ORIG_HOME" ]; then run cmd package set-home-activity "$ORIG_HOME"; fi

info "4/4 Ajouts"
ADDED="$(comm -13 "$B/packages-installed.txt" "$NOW_INST" | tr '\n' ' ')"
if [ -n "${ADDED// /}" ]; then
  echo "  Applis ajoutées depuis la sauvegarde : $ADDED"
  if [ "$RM_APPS" = 1 ] && [ "$DRY" = 0 ] && confirm "  Les désinstaller ?"; then
    for p in $ADDED; do adb_ uninstall "$p" </dev/null; log_action "restore: uninstall $p"; done
  else echo "  (conservées — ajoute --remove-added-apps pour les retirer)"; fi
fi
if [ "$RM_WP" = 1 ] && [ -f "$STATE_DIR/wallpapers-dest" ]; then run rm -r "$(cat "$STATE_DIR/wallpapers-dest")"; fi

[ "$DRY" = 1 ] && { info "Simulation terminée, rien n'a été modifié."; exit 0; }

info "Vérification"
OK=1
pkg_list -d | diff -q - "$B/packages-disabled.txt" >/dev/null || { echo "  ❌ paquets désactivés différents :"; pkg_list -d | diff - "$B/packages-disabled.txt" || true; OK=0; }
comm -23 "$B/packages-installed.txt" <(pkg_list) | grep -q . && { echo "  ❌ paquets manquants"; OK=0; }
[ -z "$ORIG_HOME" ] || [ "$(current_home)" = "$ORIG_HOME" ] || { echo "  ❌ accueil : $(current_home) ≠ $ORIG_HOME"; OK=0; }
go_home; shot apres-restauration
if [ "$OK" = 1 ]; then info "✅ État des paquets, réglages suivis et écran d'accueil identiques à la sauvegarde."; else exit 1; fi
