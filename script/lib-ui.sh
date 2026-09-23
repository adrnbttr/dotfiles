#!/usr/bin/env bash
# Affichage partagé des scripts d'installation : étapes numérotées, barre de
# progression, journal complet et résumé final.
#
#   source script/lib-ui.sh
#   ui_init "installation" 12          # titre + nombre d'étapes prévues
#   step "wezterm" "WezTerm"  ensure_wezterm_linux
#   ui_summary                         # tableau final + code de sortie
#
# Chaque étape est isolée : elle ne peut pas interrompre le script. Sa sortie
# va dans le journal ; seul son résultat s'affiche.
#
# Variables lues :
#   DOTFILES_DRY_RUN=1   n'exécute rien, affiche ce qui serait fait
#   DOTFILES_ONLY="a b"  n'exécute que ces étapes
#   DOTFILES_SKIP="a b"  saute ces étapes
#   NO_COLOR=1           sortie sans couleur

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  UI_RESET=$'\e[0m'; UI_BOLD=$'\e[1m'; UI_DIM=$'\e[2m'
  UI_GREEN=$'\e[32m'; UI_YELLOW=$'\e[33m'; UI_RED=$'\e[31m'; UI_BLUE=$'\e[36m'
else
  UI_RESET=""; UI_BOLD=""; UI_DIM=""; UI_GREEN=""; UI_YELLOW=""; UI_RED=""; UI_BLUE=""
fi

UI_TITLE=""
UI_TOTAL=0
UI_INDEX=0
UI_LOG=""
UI_START=0
UI_DONE=(); UI_SKIPPED=(); UI_FAILED=(); UI_ALREADY=()

ui_init() {
  UI_TITLE="${1:-installation}"
  UI_TOTAL="${2:-0}"
  UI_INDEX=0
  UI_START=$(date +%s)
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  mkdir -p "$dir" 2>/dev/null || true
  UI_LOG="$dir/$(date +%Y%m%d-%H%M%S).log"
  : > "$UI_LOG" 2>/dev/null || UI_LOG="/tmp/dotfiles-install.log"
  printf '%s\n' "=== $UI_TITLE $(date -Is) ===" >> "$UI_LOG"
  printf '\n%s%s dotfiles · %s%s\n' "$UI_BOLD" "❯" "$UI_TITLE" "$UI_RESET"
  printf '%s  journal : %s%s\n\n' "$UI_DIM" "$UI_LOG" "$UI_RESET"
}

ui_log() { printf '%s\n' "$*" >> "$UI_LOG" 2>/dev/null || true; }

# Barre de progression « [####----] 4/12 »
ui_bar() {
  local done=$1 total=$2 width=16 filled i out=""
  (( total > 0 )) || total=1
  filled=$(( done * width / total ))
  for ((i = 0; i < width; i++)); do
    if (( i < filled )); then out+="█"; else out+="·"; fi
  done
  printf '%s' "$out"
}

ui_say() { printf '%s%s%s\n' "$UI_DIM" "$*" "$UI_RESET"; }
ui_warn() { printf '%s! %s%s\n' "$UI_YELLOW" "$*" "$UI_RESET"; ui_log "WARN $*"; }
ui_error() { printf '%s✗ %s%s\n' "$UI_RED" "$*" "$UI_RESET"; ui_log "ERROR $*"; }

# step <id> <libellé> <commande...>
step() {
  local id="$1" label="$2"; shift 2
  UI_INDEX=$((UI_INDEX + 1))

  if [[ -n "${DOTFILES_ONLY:-}" && " ${DOTFILES_ONLY} " != *" $id "* ]]; then
    UI_SKIPPED+=("$id"); return 0
  fi
  if [[ -n "${DOTFILES_SKIP:-}" && " ${DOTFILES_SKIP} " == *" $id "* ]]; then
    printf '  %s[%s] %s — ignoré (--skip)%s\n' "$UI_DIM" "$(ui_bar "$UI_INDEX" "$UI_TOTAL")" "$label" "$UI_RESET"
    UI_SKIPPED+=("$id"); return 0
  fi

  # Padding calculé sur les caractères (printf %-28s compte les octets : les
  # libellés accentués seraient décalés).
  local pad=$(( 28 - ${#label} ))
  (( pad < 1 )) && pad=1
  printf '  %s[%s]%s %s%s%s%*s' "$UI_BLUE" "$(ui_bar "$UI_INDEX" "$UI_TOTAL")" "$UI_RESET" \
    "$UI_BOLD" "$label" "$UI_RESET" "$pad" ""

  if [[ "${DOTFILES_DRY_RUN:-}" == "1" ]]; then
    printf ' %s(simulation : %s)%s\n' "$UI_DIM" "$*" "$UI_RESET"
    UI_SKIPPED+=("$id"); return 0
  fi

  local t0 t1 rc out
  t0=$(date +%s)
  ui_log "--- step $id: $*"
  # Isolée : une étape qui échoue n'interrompt pas l'installation.
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  t1=$(date +%s)
  printf '%s\n' "$out" >> "$UI_LOG" 2>/dev/null || true

  if (( rc == 0 )); then
    if grep -qiE 'already (installed|present)|déjà' <<<"$out"; then
      printf ' %s✓ déjà là%s %s(%ss)%s\n' "$UI_GREEN" "$UI_RESET" "$UI_DIM" "$((t1 - t0))" "$UI_RESET"
      UI_ALREADY+=("$id")
    else
      printf ' %s✓%s %s(%ss)%s\n' "$UI_GREEN" "$UI_RESET" "$UI_DIM" "$((t1 - t0))" "$UI_RESET"
      UI_DONE+=("$id")
    fi
  else
    printf ' %s✗ échec%s %s(voir le journal)%s\n' "$UI_RED" "$UI_RESET" "$UI_DIM" "$UI_RESET"
    printf '%s    %s%s\n' "$UI_DIM" "$(tail -2 <<<"$out" | head -1 | cut -c1-100)" "$UI_RESET"
    UI_FAILED+=("$id")
  fi
  return 0
}

ui_summary() {
  local total=$(( ${#UI_DONE[@]} + ${#UI_ALREADY[@]} + ${#UI_SKIPPED[@]} + ${#UI_FAILED[@]} ))
  local secs=$(( $(date +%s) - UI_START ))
  printf '\n%s─────────────────────────────────────────────%s\n' "$UI_DIM" "$UI_RESET"
  printf '%s%s : terminée en %sm%ss%s · %s installées · %s déjà là · %s ignorées · %s%s en échec%s\n' \
    "$UI_BOLD" "$UI_TITLE" "$((secs / 60))" "$((secs % 60))" "$UI_RESET" \
    "${#UI_DONE[@]}" "${#UI_ALREADY[@]}" "${#UI_SKIPPED[@]}" \
    "$([[ ${#UI_FAILED[@]} -gt 0 ]] && printf '%s' "$UI_RED")" "${#UI_FAILED[@]}" "$UI_RESET"
  if (( ${#UI_FAILED[@]} > 0 )); then
    printf '\n%sÉtapes en échec :%s %s\n' "$UI_RED" "$UI_RESET" "${UI_FAILED[*]}"
    printf 'Pour les rejouer seules :\n  %s./script/install --only "%s"%s\n' "$UI_BOLD" "${UI_FAILED[*]}" "$UI_RESET"
    printf 'Détail : %s\n' "$UI_LOG"
    return 1
  fi
  printf 'Journal : %s\n' "$UI_LOG"
  return 0
}
