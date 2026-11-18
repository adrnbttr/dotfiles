#!/usr/bin/env bash
# Lance les tests web-pane (sans X ni Brave : faux xdotool/xprop/zenity/brave-browser dans le PATH).
set -u
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/script_test.sh"
