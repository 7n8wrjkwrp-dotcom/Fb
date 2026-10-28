#!/usr/bin/env bash
# Étape 5a : installe Projectivy Launcher et en fait l'écran d'accueil (réversible).
# Usage : ./04-launcher.sh                    ouvre la fiche Play Store sur la télé (tu cliques « Installer »)
#         ./04-launcher.sh --apk fichier.apk  installe un APK que tu as téléchargé toi-même
#         ./04-launcher.sh --disable-stock-launcher   (RISQUÉ, voir plus bas — demande confirmation)
. "$(dirname "$0")/lib.sh"
require_device
BACKUP="$(require_initial_backup)"

APK=""; DISABLE_STOCK=0
while [ $# -gt 0 ]; do case "$1" in
  --apk) APK="$2"; shift;; --disable-stock-launcher) DISABLE_STOCK=1;; *) die "Option inconnue : $1";; esac; shift; done

if pkg_installed "$PROJECTIVY_PKG"; then
  info "Projectivy est déjà installé."
elif [ -n "$APK" ]; then
  adb_ install "$APK"; log_action "install $APK"
else
  info "Ouverture de la fiche Projectivy Launcher dans le Play Store de la télé…"
  sh_ am start -a android.intent.action.VIEW -d "market://details?id=$PROJECTIVY_PKG" >/dev/null
  shot playstore-projectivy
  echo "Sur la télé : clique « Installer ». J'attends (5 min max)…"
  for _ in $(seq 1 100); do pkg_installed "$PROJECTIVY_PKG" && break; sleep 3; done
  pkg_installed "$PROJECTIVY_PKG" || die "Projectivy n'est pas installé."
  log_action "install $PROJECTIVY_PKG (Play Store)"
fi

COMP="$(sh_ cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
        | grep "^$PROJECTIVY_PKG/" | head -n 1 || true)"
[ -n "$COMP" ] || die "Activité d'accueil Projectivy introuvable."
info "Définition de Projectivy comme écran d'accueil par défaut ($COMP)"
sh_ cmd package set-home-activity "$COMP" || echo "  ⚠️  set-home-activity refusé : active « Remplacer le lanceur » dans Projectivy (voir README)."
log_action "set-home-activity $COMP (origine : $(cat "$BACKUP/home-activity.txt"))"
go_home; shot accueil-projectivy
echo "Écran d'accueil actuel : $(current_home)"

if [ "$DISABLE_STOCK" = 1 ]; then
  cat <<TXT

⚠️  ACTION RISQUÉE : désactiver le lanceur d'origine ($STOCK_LAUNCHER_PKG).
   Si Projectivy plantait, la clé n'aurait plus d'écran d'accueil (écran noir sur le bouton Home).
   Ça reste réversible via ADB : adb shell pm enable $STOCK_LAUNCHER_PKG  (ou ./restore.sh),
   mais il faut alors un ordinateur. Ne le fais que si Projectivy fonctionne depuis quelques jours
   et que le bouton Home revient encore sur l'ancien lanceur malgré l'option « Remplacer le lanceur ».
TXT
  [ "$(current_home)" = "$COMP" ] || die "Projectivy n'est pas l'accueil actuel : je refuse."
  read -r -p "Tape OUI en majuscules pour confirmer : " a </dev/tty
  [ "$a" = "OUI" ] || die "Annulé."
  sh_ pm disable-user --user 0 "$STOCK_LAUNCHER_PKG" >/dev/null; log_action "disable $STOCK_LAUNCHER_PKG"
  go_home; shot apres-desactivation-lanceur-origine
fi
