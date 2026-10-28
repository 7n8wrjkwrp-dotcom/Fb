#!/usr/bin/env bash
# Étape 5b : envoie des fonds d'écran foot sur la clé (dossier /sdcard/Pictures/FondsFoot).
# Usage : ./05-wallpapers.sh --photos ~/Images/foot          tes propres photos (jpg/png)
#         ./05-wallpapers.sh --commons ["Catégorie Commons"] [nombre]   photos libres de droits
. "$(dirname "$0")/lib.sh"
require_device

DEST="/sdcard/Pictures/FondsFoot"
LOCAL="$STATE_DIR/wallpapers"
case "${1:-}" in
  --photos)
    [ -d "${2:-}" ] || die "Dossier de photos introuvable : ${2:-}"
    mkdir -p "$LOCAL"; find "$2" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec cp {} "$LOCAL/" \;;;
  --commons)
    command -v python3 >/dev/null || die "python3 requis pour --commons"
    python3 -I "$ROOT/commons_fetch.py" "$LOCAL" "${2:-Quality images of association football}" "${3:-20}";;
  *) die "Usage : $0 --photos <dossier> | --commons [catégorie] [nombre]";;
esac

sh_ mkdir -p "$DEST"
for f in "$LOCAL"/*; do adb_ push "$f" "$DEST/" >/dev/null; done
# Fait apparaître les images dans les sélecteurs de fichiers / galeries
sh_ am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$DEST" >/dev/null 2>&1 || true
echo "$DEST" > "$STATE_DIR/wallpapers-dest"; log_action "push wallpapers -> $DEST"
info "$(sh_ ls "$DEST" | wc -l | tr -d ' ') fichier(s) dans $DEST sur la clé."
echo "Dans Projectivy : Paramètres > Fond d'écran > choisis le dossier $DEST (voir README)."
