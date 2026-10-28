#!/usr/bin/env bash
# Étape 5c : retrouve tes applis favorites sur la clé et donne l'ordre du dock Projectivy.
# Pour celles qui manquent et existent sur le Play Store, propose d'ouvrir leur fiche (tu installes avec la télécommande).
. "$(dirname "$0")/lib.sh"
require_device

APPS="$STATE_DIR/.launchable"; launchable_pkgs > "$APPS"
OUT="$STATE_DIR/favorites-resolved.tsv"; : > "$OUT"
MISSING=""
echo "Ordre du dock :"
grep -v '^#' "$ROOT/favorites.tsv" | while IFS='	' read -r n name re store; do
  found="$( (grep -Ei "$re" "$APPS" || true) | tr '\n' ' ' | sed 's/ $//')"
  [ "$name" = "Play Store" ] && [ -z "$found" ] && pkg_installed com.android.vending && found="com.android.vending"
  if [ -n "$found" ]; then
    printf '  %2s. ✅ %-20s %s\n' "$n" "$name" "$found"
  elif [ -n "${store:-}" ]; then
    printf '  %2s. ❌ %-20s absente (Play Store : %s)\n' "$n" "$name" "$store"
  else
    printf '  %2s. ❓ %-20s introuvable automatiquement — dis-moi son nom exact sur la télé\n' "$n" "$name"
  fi
  printf '%s\t%s\t%s\t%s\n' "$n" "$name" "$found" "${store:-}" >> "$OUT"
done
echo "  (King365 V4 et V2 : vérifie lequel est lequel dans Projectivy si deux paquets « king » apparaissent.)"

while IFS='	' read -r n name found store; do
  [ -z "$found" ] && [ -n "$store" ] || continue
  if confirm "Ouvrir la fiche Play Store de $name sur la télé pour l'installer ?"; then
    sh_ am start -a android.intent.action.VIEW -d "market://details?id=$store" >/dev/null
    shot "playstore-$store"
    read -r -p "  Installe-la avec la télécommande puis appuie sur Entrée… " _ </dev/tty 2>/dev/null || true
    log_action "open play store $store"
  fi
done < "$OUT"
go_home; shot favoris
echo "Résultat : $OUT — ajoute ces applis au dock de Projectivy dans cet ordre (voir README)."
