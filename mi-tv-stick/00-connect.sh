#!/usr/bin/env bash
# Étape 1 : vérifie ADB, trouve la clé sur le Wi-Fi et s'y connecte.
# Usage : ./00-connect.sh            (recherche automatique sur le réseau local)
#         ./00-connect.sh 192.168.1.42
. "$(dirname "$0")/lib.sh"

if ! command -v "$ADB" >/dev/null 2>&1; then
  cat <<'TXT'
ADB n'est pas installé. Installe les « Android platform-tools » :
  • macOS   : brew install android-platform-tools
  • Debian/Ubuntu : sudo apt install adb
  • Fedora  : sudo dnf install android-tools
  • Windows : winget install Google.PlatformTools
              (ou zip officiel : https://developer.android.com/tools/releases/platform-tools)
Puis relance ce script.
TXT
  exit 1
fi
info "ADB trouvé : $("$ADB" version | head -n 1)"

cat <<'TXT'

Sur la clé (une seule fois) :
  1. Paramètres > Préférences de l'appareil > À propos > clique 7 fois sur « Build »
     (message « Vous êtes maintenant développeur »).
  2. Paramètres > Préférences de l'appareil > Options pour les développeurs
     > active « Débogage USB » (sur cette clé, il ouvre aussi l'ADB réseau, port 5555).
  3. Adresse IP : Paramètres > Réseau et Internet > ton Wi-Fi.

TXT

local_prefix() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
  elif command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  [ -n "$ip" ] && echo "${ip%.*}"
}

scan_5555() {
  local prefix="$1" i
  info "Recherche des appareils ADB sur $prefix.0/24 (port 5555)…" >&2
  for i in $(seq 1 254); do
    ( if command -v nc >/dev/null 2>&1; then
        nc -z -w 1 "$prefix.$i" 5555 >/dev/null 2>&1 && echo "$prefix.$i"
      else
        (exec 3<>"/dev/tcp/$prefix.$i/5555") >/dev/null 2>&1 && echo "$prefix.$i"
      fi ) &
    [ $((i % 64)) -eq 0 ] && wait
  done
  wait
}

IP="${1:-}"
if [ -z "$IP" ]; then
  CANDIDATES="$("$ADB" mdns services 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u || true)"
  if [ -z "$CANDIDATES" ]; then
    PREFIX="$(local_prefix || true)"
    [ -n "$PREFIX" ] || die "Impossible de déterminer ton réseau local. Donne l'IP de la clé : ./00-connect.sh 192.168.x.y"
    CANDIDATES="$(scan_5555 "$PREFIX" | sort -t. -k4 -n)"
  fi
  [ -n "$CANDIDATES" ] || die "Aucun appareil avec ADB réseau trouvé. Vérifie le débogage sur la clé, ou donne son IP."
  echo "Appareils trouvés :"; echo "$CANDIDATES" | sed 's/^/  - /'
  IP="$(echo "$CANDIDATES" | head -n 1)"
  if [ "$(echo "$CANDIDATES" | wc -l)" -gt 1 ]; then
    ans=""; read -r -p "IP de la clé [$IP] : " ans </dev/tty || true
    IP="${ans:-$IP}"
  fi
fi
case "$IP" in *:*) TARGET="$IP";; *) TARGET="$IP:5555";; esac

info "Connexion à $TARGET… (accepte « Autoriser le débogage » sur la télé, coche « Toujours autoriser »)"
"$ADB" connect "$TARGET" || true
for _ in $(seq 1 30); do
  st="$("$ADB" -s "$TARGET" get-state 2>/dev/null | tr -d '\r' || true)"
  [ "$st" = "device" ] && break
  sleep 2; "$ADB" connect "$TARGET" >/dev/null 2>&1 || true
done
[ "${st:-}" = "device" ] || die "Connexion non autorisée. Regarde la télé : une fenêtre demande l'autorisation."

echo "$TARGET" > "$DEVICE_FILE"; DEVICE="$TARGET"
info "Connecté : $(sh_ getprop ro.product.manufacturer) $(sh_ getprop ro.product.model) — Android $(sh_ getprop ro.build.version.release)"
shot connexion
