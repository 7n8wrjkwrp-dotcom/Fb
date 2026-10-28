#!/usr/bin/env bash
# Étape 3 : liste les applis/fonctions candidates à la désactivation, par catégorie.
# Lecture seule. Produit state/candidates.tsv (catégorie, paquet, description, état, note) utilisé par 03-disable.sh.
. "$(dirname "$0")/lib.sh"
require_device

INSTALLED="$STATE_DIR/.installed"; ENABLED="$STATE_DIR/.enabled"
pkg_list > "$INSTALLED"; pkg_list -e > "$ENABLED"
OUT="$STATE_DIR/candidates.tsv"; : > "$OUT"

grep -v '^#' "$ROOT/catalog.tsv" | while IFS='	' read -r cat pkg desc note; do
  [ -n "${pkg:-}" ] || continue
  grep -Fxq "$pkg" "$INSTALLED" || continue
  is_critical "$pkg" && continue
  is_favorite "$pkg" && continue
  if grep -Fxq "$pkg" "$ENABLED"; then st="actif"; else st="déjà désactivé"; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$cat" "$pkg" "$desc" "$st" "${note:-}" >> "$OUT"
done

# Applis Xiaomi / MiTV : pas de description fiable d'avance, on les examine ensemble.
grep -E '^com\.(xiaomi|mitv|mi|miui)\.' "$INSTALLED" | while read -r pkg; do
  is_critical "$pkg" && continue
  is_favorite "$pkg" && continue
  grep -q "	$pkg	" "$OUT" && continue
  if grep -Fxq "$pkg" "$ENABLED"; then st="actif"; else st="déjà désactivé"; fi
  printf 'XIAOMI\t%s\t%s\t%s\t%s\n' "$pkg" "Appli Xiaomi (rôle à vérifier)" "$st" "Probables pubs/services fabricant" >> "$OUT"
done

label() { case "$1" in
  PUB) echo "📢 Pubs / contenus sponsorisés";; TELEMETRIE) echo "📡 Télémétrie";;
  INUTILE) echo "🗑️  Applis inutiles";; XIAOMI) echo "🏭 Fabricant Xiaomi (à examiner)";;
  UTILE) echo "⭐ Ce que tu pourrais utiliser (accord requis un par un)";; esac; }

for c in PUB TELEMETRIE XIAOMI INUTILE UTILE; do
  grep -q "^$c	" "$OUT" || continue
  echo; label "$c"
  grep "^$c	" "$OUT" | while IFS='	' read -r _ pkg desc st note; do
    printf '  %-48s %s [%s]%s\n' "$pkg" "$desc" "$st" "${note:+ — $note}"
  done
done

echo; echo "🔍 Autres applis non répertoriées (pour info, non proposées automatiquement) :"
comm -23 "$ENABLED" <(cut -f2 "$OUT" | sort -u) | while read -r pkg; do
  is_critical "$pkg" || is_favorite "$pkg" || echo "  $pkg"
done | grep -Ev '^  com\.android\.(cts|wallpaper|backup|sharedstorage|dynsystem|localtransport|proxyhandler|vpndialogs|certinstaller|carrierdefaultapp|companiondevicemanager|statementservice|egg|pacprocessor|mtp|calllogbackup|emergency|smspush)' || true
echo; echo "Liste enregistrée : $OUT"
log_action "candidates $(wc -l < "$OUT" | tr -d ' ') entrées"
