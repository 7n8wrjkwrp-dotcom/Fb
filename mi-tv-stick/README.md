# Xiaomi Mi TV Stick : allègement réversible et écran d'accueil minimaliste

Ces scripts tournent sur **ton ordinateur**, sur le même Wi-Fi que la clé (macOS, Linux, ou Windows via Git Bash ou WSL).
Ils ne **désinstallent rien** : on utilise seulement `pm disable-user` et des réglages qu'on peut remettre, et chaque modification est notée dans `state/`.

| Étape | Commande | Ce qu'elle fait |
|---|---|---|
| 1 | `./00-connect.sh [IP]` | Vérifie ADB (sinon donne la commande d'installation), cherche la clé sur le Wi-Fi et s'y connecte |
| 2 | `./01-backup.sh` | Sauvegarde complète : paquets et leur état, réglages `global/secure/system`, écran d'accueil, `dumpsys`, captures d'écran |
| 3 | `./02-candidates.sh` | Liste les candidats par catégorie : pubs, télémétrie, fabricant Xiaomi, inutiles, utiles. **Ne modifie rien** |
| 4 | `./03-disable.sh` | Te pose une question par appli (réponse par défaut : **non**). Les applis critiques sont toujours refusées |
| 5a | `./04-launcher.sh` | Installe Projectivy Launcher depuis le Play Store de la télé et en fait l'écran d'accueil |
| 5b | `./05-wallpapers.sh --photos DOSSIER` ou `--commons` | Envoie des fonds d'écran foot (tes photos, ou photos libres de Wikimedia Commons avec `CREDITS.txt`) |
| 5c | `./06-favorites.sh` | Retrouve tes applis favorites sur la clé, donne l'ordre du dock et propose d'ouvrir la page Play Store de celles qui manquent |
| 6 | `./restore.sh [--dry-run]` | Remet l'état de la sauvegarde de référence et vérifie |

Chaque étape fait une capture de la télé dans `state/shots/` (ou dans `state/backup-*/shots/` pour la sauvegarde).

## Garde-fous
- `01-backup.sh` doit avoir tourné avant toute modification : les autres scripts refusent de démarrer sans lui. La **première** sauvegarde sert de référence pour la restauration.
- Liste noire codée en dur dans `lib.sh` : services Google Play, Play Store, interface système, paramètres, assistant de configuration, service de la télécommande, clavier, pilotes Amlogic, etc. Ces paquets ne sont jamais désactivés, même s'ils figurent dans une liste fournie.
- Les applis classées « ⭐ utile » (micro et Assistant, Chromecast, YouTube, Netflix…) demandent un accord séparé, avec un avertissement.
- **Action risquée, à part** : `./04-launcher.sh --disable-stock-launcher` désactive le lanceur d'origine. Le script refuse si Projectivy n'est pas l'accueil actuel, puis demande de taper `OUI`. N'y recours que si le bouton Home revient encore à l'ancien lanceur.

## Applis favorites (protégées)
Listées dans `favorites.tsv`. Aucun script ne les propose ni ne les désactive.
Ordre du dock : **YouTube · SmartTube Beta · Netflix · Prime Video · Paramount+ · Crunchyroll · Spotify · Twitch · Kick · King365 V4 · King365 V2 · Navigateur web · Downloader · Play Store**.
La première ligne visible (6 icônes) regroupe la vidéo, comme sur Apple TV. Les outils (navigateur, Downloader, Play Store) sont rangés à la fin.
SmartTube, Kick et King365 ne viennent pas du Play Store : le script les cherche seulement s'ils sont déjà installés et ne télécharge aucun APK.

## Configurer Projectivy façon Apple TV (sur la télé, avec la télécommande)
1. Dans les réglages de Projectivy, active l'option qui remplace le lanceur actuel (« Override current launcher »), pour que le bouton Home ouvre Projectivy.
2. Garde **une seule ligne** de chaînes (le « dock ») et masque les autres lignes et catégories.
3. Ajoute tes applis préférées dans le dock et range-les dans l'ordre voulu (appui long sur une icône, puis déplacer).
4. Fond d'écran : choisis le dossier `/sdcard/Pictures/FondsFoot` rempli par `05-wallpapers.sh`, et active la rotation si ta version de Projectivy la propose (à vérifier sur place).
5. Thème sombre, horloge seule en haut : c'est le look le plus proche d'Apple TV.

## Restaurer
```bash
./restore.sh --dry-run          # montre ce qui serait fait, sans rien toucher
./restore.sh                    # réactive tout, remet réglages et accueil d'origine, puis vérifie
./restore.sh --remove-added-apps --remove-wallpapers   # retire aussi Projectivy et les images (avec confirmation)
```
En urgence, depuis n'importe quel ordinateur : `adb connect IP:5555`, puis `adb shell pm enable <paquet>`.
Pour le lanceur d'origine : `adb shell pm enable com.google.android.tvlauncher`.

## Tests
`tests/run.sh` enchaîne sauvegarde, désactivation, lanceur et restauration sur une **clé simulée** (`tests/mock-adb`).
Il vérifie que la restauration retrouve exactement l'état initial et que les paquets critiques sont refusés.
Ça ne remplace pas un essai sur la vraie clé.
