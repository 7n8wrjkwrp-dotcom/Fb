#!/usr/bin/env bash
# Étape 4 : désactive (pm disable-user, réversible) UNIQUEMENT ce que tu valides.
# Usage : ./03-disable.sh                   questions une par une (réponse par défaut : NON)
#         ./03-disable.sh --from-file approved.txt   liste validée à l'avance (un paquet par ligne)
#         ./03-disable.sh --dry-run          n'exécute rien, affiche ce qui serait fait
# Aucune désinstallation. Réactivation : ./restore.sh  (ou adb shell pm enable <paquet>)
. "$(dirname "$0")/lib.sh"
require_device
require_initial_backup >/dev/null

DRY=0; FILE=""
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1;; --from-file) FILE="$2"; shift;; *) die "Option inconnue : $1";; esac; shift; done

CAND="$STATE_DIR/candidates.tsv"
[ -f "$CAND" ] || die "Lance d'abord ./02-candidates.sh"
APPROVED="$STATE_DIR/approved-$(date +%Y%m%d-%H%M%S).txt"; : > "$APPROVED"

if [ -n "$FILE" ]; then
  grep -Ev '^[[:space:]]*(#|$)' "$FILE" | awk '{print $1}' > "$APPROVED"
else
  echo "Réponds o pour désactiver, Entrée pour garder."
  while IFS='	' read -r cat pkg desc st note; do
    [ "$st" = "actif" ] || continue
    q="[$cat] $pkg — $desc${note:+ ($note)}"
    [ "$cat" = "UTILE" ] && q="⚠️  TU POURRAIS L'UTILISER — $q"
    if confirm "Désactiver $q ?"; then echo "$pkg" >> "$APPROVED"; fi
  done < "$CAND"
fi

[ -s "$APPROVED" ] || { info "Rien à désactiver."; exit 0; }
info "Paquets validés :"; sed 's/^/  - /' "$APPROVED"

FAIL=0
while read -r pkg; do
  if is_critical "$pkg"; then echo "  ⛔ $pkg refusé : paquet critique pour la stabilité."; continue; fi
  if is_favorite "$pkg"; then echo "  ⭐ $pkg refusé : appli favorite (favorites.tsv)."; continue; fi
  if ! pkg_installed "$pkg"; then echo "  ⚠️  $pkg absent, ignoré."; continue; fi
  if pkg_disabled "$pkg"; then echo "  ✔ $pkg déjà désactivé."; continue; fi
  if [ "$DRY" = 1 ]; then echo "  (simulation) pm disable-user --user 0 $pkg"; continue; fi
  sh_ pm disable-user --user 0 "$pkg" >/dev/null
  if pkg_disabled "$pkg"; then echo "  ✅ $pkg désactivé"; log_action "disable $pkg"
  else echo "  ❌ échec pour $pkg"; FAIL=1; fi
done < "$APPROVED"

if [ "$DRY" = 0 ] && confirm "Réduire la durée des animations (0,5x) pour une interface plus vive ? (réversible)"; then
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    settings_put_tracked global "$k" 0.5
  done
  echo "  ✅ animations à 0,5x"
fi

go_home; shot apres-desactivation
exit "$FAIL"
