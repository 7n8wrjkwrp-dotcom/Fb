#!/usr/bin/env bash
# Test hors appareil : sauvegarde -> désactivation -> lanceur -> restauration, sur une clé simulée.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
T="$(mktemp -d)"; trap '[ -n "${KEEP:-}" ] && echo "$T" || rm -rf "$T"' EXIT
export MOCK_DIR="$T/dev" STATE_DIR="$T/state" ADB="$HERE/mock-adb" DEVICE="192.168.1.50:5555" SHOT_DELAY=0
mkdir -p "$MOCK_DIR"
cat > "$MOCK_DIR/packages.tsv" <<'TSV'
android	1	1	1
com.android.systemui	1	1	1
com.android.vending	1	1	1
com.google.android.gms	1	1	1
com.google.android.tvlauncher	1	1	1
com.google.android.tvrecommendations	1	1	1
com.google.android.feedback	1	1	1
com.google.android.play.games	1	1	1
com.google.android.katniss	1	1	1
com.google.android.youtube.tv	1	1	1
com.netflix.ninja	1	1	1
com.mitv.tvhome.atv	1	1	1
com.android.printspooler	0	1	1
com.google.android.videos	1	0	1
TSV
echo "com.google.android.tvlauncher/.MainActivity" > "$MOCK_DIR/home"
printf 'window_animation_scale=1.0\ntransition_animation_scale=1.0\n' > "$MOCK_DIR/settings-global"
: > "$MOCK_DIR/settings-secure"; : > "$MOCK_DIR/settings-system"
cp "$MOCK_DIR/packages.tsv" "$T/initial.tsv"

fail() { echo "ÉCHEC : $*"; exit 1; }
cd "$ROOT"
./01-backup.sh > "$T/log" 2>&1 || { cat "$T/log"; fail backup; }
./02-candidates.sh > "$T/cand.out" 2>&1 || { cat "$T/cand.out"; fail candidates; }
grep -q com.mitv.tvhome.atv "$STATE_DIR/candidates.tsv" || fail "paquet Xiaomi non proposé"
grep -q com.google.android.gms "$STATE_DIR/candidates.tsv" && fail "paquet critique proposé"

printf 'com.google.android.tvrecommendations\ncom.google.android.feedback\ncom.google.android.play.games\ncom.mitv.tvhome.atv\ncom.google.android.gms  # doit être refusé\n' > "$T/approved.txt"
./03-disable.sh --from-file "$T/approved.txt" < /dev/null > "$T/dis.out" 2>&1 || true
grep -q "gms refusé" "$T/dis.out" || { cat "$T/dis.out"; fail "gms non refusé"; }
awk -F'\t' '$1=="com.google.android.feedback"&&$2==0{f=1} END{exit !f}' "$MOCK_DIR/packages.tsv" || fail "feedback non désactivé"
awk -F'\t' '$1=="com.google.android.gms"&&$2==1{f=1} END{exit !f}' "$MOCK_DIR/packages.tsv" || fail "gms touché"

# Simule le réglage d'animation accepté et l'installation du lanceur
( . ./lib.sh; settings_put_tracked global window_animation_scale 0.5; settings_put_tracked global animator_duration_scale 0.5 )
"$ADB" install fake.apk >/dev/null
./04-launcher.sh > "$T/l.out" 2>&1 || { cat "$T/l.out"; fail launcher; }
grep -q projengmenu "$MOCK_DIR/home" || fail "accueil non changé"

./restore.sh --dry-run > "$T/dry.out" 2>&1 || { cat "$T/dry.out"; fail dry-run; }
grep -q "pm enable --user 0 com.google.android.feedback" "$T/dry.out" || fail "dry-run incomplet"
./restore.sh < /dev/null > "$T/r.out" 2>&1 || { cat "$T/r.out"; fail restore; }
grep -q "✅" "$T/r.out" || fail "vérification de restauration"
diff <(grep -v projengmenu "$MOCK_DIR/packages.tsv") "$T/initial.tsv" || fail "paquets différents de l'initial"
grep -q "^window_animation_scale=1.0$" "$MOCK_DIR/settings-global" || fail "réglage non restauré"
grep -q "^animator_duration_scale=" "$MOCK_DIR/settings-global" && fail "réglage ajouté non supprimé"
grep -q tvlauncher "$MOCK_DIR/home" || fail "accueil non restauré"
echo "✅ Tous les tests passent (clé simulée)."
