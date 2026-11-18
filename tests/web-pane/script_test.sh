#!/usr/bin/env bash
# Tests de bin/.local/bin/web-pane avec de faux outils : pages, menu, appui simple, double appui,
# --menu, --has-window. Aucun X, aucun navigateur, aucun reseau ; tout dans un dossier temporaire.
# Les essais graphiques reels (Xvfb + Brave) ne font pas partie du depot.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/.local/bin/web-pane"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/cfg/web-pane" "$T/rt" "$T/data"

# --- faux outils : l'etat des fenetres vit dans $T/wins (ids, un par ligne) et $T/hidden ---
cat > "$T/bin/xdotool" <<'F'
#!/usr/bin/env bash
case $1 in
  search) cat "$FAKE_DIR/wins" 2>/dev/null ;;
  windowminimize) echo "$2" >> "$FAKE_DIR/hidden"; echo "min $2" >> "$FAKE_DIR/log" ;;
  windowactivate) : > "$FAKE_DIR/hidden"; echo "act $2" >> "$FAKE_DIR/log" ;;
  windowclose) echo "xclose $2" >> "$FAKE_DIR/log" ;;
esac
F
cat > "$T/bin/xprop" <<'F'
#!/usr/bin/env bash
case $3 in
  WM_STATE) echo "WM_STATE(WM_STATE):"; echo "		window state: Normal" ;;
  _NET_WM_STATE) if [[ -s $FAKE_DIR/hidden ]]; then echo "_NET_WM_STATE(ATOM) = _NET_WM_STATE_HIDDEN"; else echo "_NET_WM_STATE(ATOM) = "; fi ;;
esac
F
cat > "$T/bin/zenity" <<'F'
#!/usr/bin/env bash
echo "zenity $*" >> "$FAKE_DIR/log"
[[ -n ${ZENITY_RC:-} ]] && exit "$ZENITY_RC"
[[ -n ${ZENITY_CHOICE:-} ]] || exit 1
echo "$ZENITY_CHOICE"
F
cat > "$T/bin/brave-browser" <<'F'
#!/usr/bin/env bash
echo "brave $*" >> "$FAKE_DIR/log"
[[ -n ${BRAVE_NEWWIN:-} ]] && echo "$BRAVE_NEWWIN" >> "$FAKE_DIR/wins"
exit 0
F
cat > "$T/bin/notify-send" <<'F'
#!/usr/bin/env bash
echo "notify $*" >> "$FAKE_DIR/log"
F
cat > "$T/bin/wmctrl" <<'F'
#!/usr/bin/env bash
echo "wmctrl $*" >> "$FAKE_DIR/log"
F
chmod +x "$T"/bin/*

export PATH="$T/bin:$PATH" FAKE_DIR="$T"
export XDG_CONFIG_HOME="$T/cfg" XDG_RUNTIME_DIR="$T/rt" XDG_DATA_HOME="$T/data"
# WEB_PANE_TRAY defini mais vide : icone desactivee, sans repli sur un web-pane-tray installe
export WEB_PANE_TRAY='' WEB_PANE_CLASS=wp-test
pages="$T/cfg/web-pane/pages"
fails=0
check() { # check "titre" "attendu (regex)" "obtenu"
  if [[ $3 =~ $2 ]]; then echo "ok   $1"; else echo "FAIL $1 : attendu /$2/, obtenu: $3"; fails=$((fails+1)); fi
}
reset() { : > "$T/log"; : > "$T/wins"; : > "$T/hidden"; rm -f "$T"/rt/*; unset ZENITY_CHOICE ZENITY_RC BRAVE_NEWWIN; }
log() { sleep 0.3; tr '\n' '|' < "$T/log"; }   # laisse finir le brave lance en tache de fond

printf '# commentaire\n\nAlpha https://a.example/x\r\n  Beta  deux mots   https://b.example/y  \n' > "$pages"

reset; ZENITY_CHOICE="Beta  deux mots" bash "$SCRIPT"
check "plusieurs pages, sans fenetre : menu puis page choisie" 'zenity .*brave .*--app=https://b.example/y' "$(log)"

reset; bash "$SCRIPT"
check "menu annule : rien ne se lance" '^zenity [^|]*\|$' "$(log)"

reset; echo 7 > "$T/wins"; bash "$SCRIPT"; r=$(log); bash "$SCRIPT"; r2=$(log)
check "appui simple, fenetre visible : minimise, pas de menu" '^min 7\|$' "$r"
check "appui simple, fenetre minimisee : restaure" '^min 7\|act 7\|$' "$r2"

reset; echo 7 > "$T/wins"; WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"; WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"
check "double appui, Echap : etat d'avant le 1er appui (visible), menu ouvert" '^min 7\|act 7\|zenity [^|]*\|$' "$(log)"

reset; echo 7 > "$T/wins"; echo 7 > "$T/hidden"
WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"; WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"
check "double appui, Echap, fenetre minimisee au depart : redevient minimisee" '^act 7\|min 7\|zenity ' "$(log)"

reset; echo 7 > "$T/wins"; WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"; : > "$T/log"
ZENITY_CHOICE=Alpha WEB_PANE_DOUBLE_MS=2000 bash "$SCRIPT"
check "double appui + choix : nouvelle fenetre sur la page, ancienne fermee" 'act 7\|zenity .*brave .*--app=https://a.example/x' "$(log)"

reset; echo 7 > "$T/wins"; ZENITY_CHOICE="Beta  deux mots" bash "$SCRIPT" --menu
check "--menu avec fenetre : nouvelle page, pas de minimisation" 'brave .*https://b.example/y' "$(log)"

reset; ZENITY_CHOICE=Alpha bash "$SCRIPT" --menu
check "--menu sans fenetre : ouvre la page choisie" 'brave .*https://a.example/x' "$(log)"

reset; ZENITY_CHOICE=Alpha bash "$SCRIPT" --menu >/dev/null; ZENITY_CHOICE=Alpha bash "$SCRIPT" --menu; : > "$T/log"
ZENITY_CHOICE=Alpha bash "$SCRIPT" --menu; check "garde anti double lancement (5 s)" '^$' "$(log)"

reset; echo 3 > "$T/wins"; bash "$SCRIPT" --menu >/dev/null; : > "$T/log"; bash "$SCRIPT" --menu
check "menu : la page courante est marquee" 'zenity ' "$(log)"

reset; bash "$SCRIPT" --has-window; check "--has-window sans fenetre : code 1" '^1$' "$?"
echo 3 > "$T/wins"; bash "$SCRIPT" --has-window; check "--has-window avec fenetre : code 0" '^0$' "$?"

printf 'Seule https://only.example/\n' > "$pages"
reset; bash "$SCRIPT"
check "une seule page : ouverture directe sans menu" '^brave .*--app=https://only.example/\|$' "$(log)"

rm "$pages"; printf '\n  https://old.example/u  \nautre\n' > "$T/cfg/web-pane/url"
reset; bash "$SCRIPT"
check "ancien fichier url : page unique" '^brave .*--app=https://old.example/u\|$' "$(log)"

rm "$T/cfg/web-pane/url"
reset; bash "$SCRIPT" https://arg.example/
check "URL en argument" '^brave .*--app=https://arg.example/\|$' "$(log)"

reset; bash "$SCRIPT"; r=$?
check "aucune page : notification et code 1" '^1$' "$r"

# --- defauts corriges apres relecture ---------------------------------------------------------
printf 'Alpha https://a.example/x\nBeta https://b.example/y\n' > "$pages"

# 1. changement de page sans nouvelle fenetre : l'ancienne reste, notification, ~5 s (pas 10)
reset; echo 7 > "$T/wins"; t0=$SECONDS
ZENITY_CHOICE=Beta bash "$SCRIPT" --menu; dur=$(( SECONDS - t0 ))
r=$(log)
check "echec de changement de page : ancienne fenetre conservee" '^zenity [^|]*\|brave [^|]*\|notify [^|]*\|$' "$r"
check "echec de changement de page : attente bornee (4 a 7 s)" '^[4-7]$' "$dur"
reset; echo 7 > "$T/wins"; BRAVE_NEWWIN=8 ZENITY_CHOICE=Beta bash "$SCRIPT" --menu
check "changement de page reussi : ancienne fermee" 'brave [^|]*\|wmctrl -ic 7\|$' "$(log)"

# 2b. appui simple avec fenetre : l'icone est demarree (faux script d'icone)
cat > "$T/bin/fake-tray" <<'F'
#!/usr/bin/env bash
echo "tray" >> "$FAKE_DIR/log"
F
chmod +x "$T/bin/fake-tray"
reset; echo 7 > "$T/wins"; WEB_PANE_TRAY="$T/bin/fake-tray" bash "$SCRIPT"
check "appui simple, fenetre presente : icone demarree" 'tray' "$(log)"

# 3. nom commencant par "-" : "--" avant les lignes ; zenity en erreur : notification avec le code
printf -- '-perso https://p.example/\nBeta https://b.example/y\n' > "$pages"
reset; ZENITY_CHOICE=-perso bash "$SCRIPT"
check "nom de page en tiret : '--' avant les lignes, page ouverte" 'zenity [^|]* -- [^|]*-perso[^|]*\|brave .*--app=https://p.example/' "$(log)"
reset; ZENITY_RC=255 bash "$SCRIPT"
check "zenity en erreur : notification avec le code, rien lance" '^zenity [^|]*\|notify [^|]*255[^|]*\|$' "$(log)"
reset; ZENITY_RC=1 bash "$SCRIPT"
check "zenity annule (code 1) : pas de notification" '^zenity [^|]*\|$' "$(log)"

# 4. WEB_PANE_TRAY defini : jamais de repli sur un web-pane-tray du PATH
mkdir -p "$T/stowed"
# shellcheck disable=SC2016 # le faux script doit garder $FAKE_DIR litteral
printf '#!/usr/bin/env bash\necho "VRAI tray" >> "$FAKE_DIR/log"\n' > "$T/stowed/web-pane-tray"
chmod +x "$T/stowed/web-pane-tray"
printf 'Seule https://only.example/\n' > "$pages"
reset; PATH="$PATH:$T/stowed" WEB_PANE_TRAY=/nonexistent bash "$SCRIPT"
check "WEB_PANE_TRAY defini et introuvable : pas de repli" '^brave [^|]*\|$' "$(log)"
reset; PATH="$PATH:$T/stowed" WEB_PANE_TRAY='' bash "$SCRIPT"
check "WEB_PANE_TRAY vide : icone desactivee" '^brave [^|]*\|$' "$(log)"
# copie du script dans un dossier sans web-pane-tray voisin (sinon le vrai serait lance)
mkdir -p "$T/solo"; cp "$SCRIPT" "$T/solo/web-pane"
reset; (unset WEB_PANE_TRAY; PATH="$PATH:$T/stowed" bash "$T/solo/web-pane")
check "WEB_PANE_TRAY non defini : repli sur le PATH" 'VRAI tray' "$(log)"

# 5. analyse de pages : URL seule acceptee (nom = URL), doublon refuse avec une seule notification
printf 'https://seule.example/\nAlpha https://a.example/\n' > "$pages"
reset; ZENITY_CHOICE=https://seule.example/ bash "$SCRIPT"
check "ligne URL seule : acceptee, l'URL sert de nom" 'zenity [^|]*\|brave .*--app=https://seule.example/' "$(log)"
printf 'Mail https://a.example/\nMail https://b.example/\nMail https://c.example/\nAutre https://d.example/\n' > "$pages"
reset; ZENITY_CHOICE=Mail bash "$SCRIPT"; r=$(log)
check "nom en double : la premiere page est gardee" 'brave .*--app=https://a.example/' "$r"
check "noms en double : une seule notification" '^zenity [^|]*\|brave [^|]*\|notify [^|]*\|$|^notify [^|]*\|zenity [^|]*\|brave [^|]*\|$' "$r"

# 2a. l'icone (web-pane-tray) : un lancement recent compte comme une presence (gi factice)
mkdir -p "$T/fakegi/gi/repository"
cat > "$T/fakegi/gi/__init__.py" <<'F'
def require_version(*a): pass
F
cat > "$T/fakegi/gi/repository/__init__.py" <<'F'
# Horloge virtuelle : Gtk.main fait avancer time.time/time.monotonic de 2 s par sondage.
import os, time
_off = [0.0]
_real_time, _real_mono = time.time, time.monotonic
time.time = lambda: _real_time() + _off[0]
time.monotonic = lambda: _real_mono() + _off[0]
class _GLib:
    cbs = []
    @staticmethod
    def timeout_add_seconds(s, cb): _GLib.cbs.append((s, cb))
GLib = _GLib
class _Gtk:
    run = True
    @staticmethod
    def main():
        for _ in range(40):
            if not _Gtk.run: return
            for s, cb in list(_GLib.cbs):
                _off[0] += s
                cb()
    @staticmethod
    def main_quit():
        _Gtk.run = False
        open(os.environ["FAKE_DIR"] + "/tray_quit", "w").write("%d" % _off[0])
Gtk = _Gtk
class _Icon:
    def __getattr__(self, n): return lambda *a, **k: None
class XApp:
    StatusIcon = _Icon
F
cat > "$T/bin/nowin" <<'F'
#!/usr/bin/env bash
exit 1
F
chmod +x "$T/bin/nowin"
TRAY="$ROOT/bin/.local/bin/web-pane-tray"
run_tray() { # $1 = "launch" pour ecrire un lancement recent ; imprime le temps virtuel de l'arret
  rm -f "$T/tray_quit" "$T"/rt/*
  [[ ${1:-} == launch ]] && date +%s > "$T/rt/web-pane-wp-test.launch"
  PYTHONPATH="$T/fakegi" WEB_PANE_CMD="$T/bin/nowin" timeout 20 python3 "$TRAY" >/dev/null 2>&1
  cat "$T/tray_quit" 2>/dev/null
}
r=$(run_tray)
check "icone sans fenetre ni lancement : s'arrete apres le delai de grace" '^([6-9]|10)$' "$r"
r=$(run_tray launch)
check "icone, lancement recent : reste au moins 15 s" '^(1[6-9]|[2-9][0-9])$' "$r"

(( fails == 0 )) && echo "Tous les tests passent." || echo "$fails echec(s)."
exit $(( fails > 0 ))
