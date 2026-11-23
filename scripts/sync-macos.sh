#!/bin/bash
# Безопасная синхронизация только двух репозиториев навыков с личного GitHub.
# Не обновляет содержимое сторонних upstream-репозиториев и не затрагивает семейные дела.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

BASE="${HOME}/Мак-Документы/Гитхаб+Клод"
FAILED=0
UPDATED=0

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

notify() {
  local message="$1"
  if [[ -x /usr/bin/osascript ]]; then
    /usr/bin/osascript -e "display notification \"${message}\" with title \"Исторические навыки GitHub\"" >/dev/null 2>&1 || true
  fi
}

sync_one() {
  local name="$1" folder="$2" remote branch status before target count after root
  log "Проверка: ${name}"
  if [[ ! -d "$folder" ]]; then
    log "ПРОПУСК: папка не найдена: ${folder}"
    FAILED=1
    return 0
  fi
  if ! root="$(git -C "$folder" rev-parse --show-toplevel 2>/dev/null)"; then
    log "ПРОПУСК: это не Git-репозиторий: ${folder}"
    FAILED=1
    return 0
  fi
  if [[ "$(cd "$root" && pwd -P)" != "$(cd "$folder" && pwd -P)" ]]; then
    log "ПРОПУСК: путь указывает на вложенную папку другого Git-репозитория"
    FAILED=1
    return 0
  fi
  if ! remote="$(git -C "$folder" remote get-url origin 2>/dev/null)"; then
    log "ПРОПУСК: отсутствует origin"
    FAILED=1
    return 0
  fi
  case "$remote" in
    "https://github.com/9479797/${name}"|"https://github.com/9479797/${name}.git"|"git@github.com:9479797/${name}"|"git@github.com:9479797/${name}.git") ;;
    *)
      log "ПРОПУСК: неподтверждённый origin: ${remote}"
      FAILED=1
      return 0
      ;;
  esac
  branch="$(git -C "$folder" branch --show-current 2>/dev/null)"
  if [[ "$branch" != "main" ]]; then
    log "ПРОПУСК: активна ветка '${branch}', ожидалась main"
    FAILED=1
    return 0
  fi
  if [[ -n "$(git -C "$folder" status --porcelain --untracked-files=all)" ]]; then
    log "ПРОПУСК: имеются несохранённые локальные изменения или новые файлы"
    FAILED=1
    return 0
  fi
  if ! git -C "$folder" fetch --quiet --no-tags origin main; then
    log "ОШИБКА: невозможно получить изменения из GitHub"
    FAILED=1
    return 0
  fi
  before="$(git -C "$folder" rev-parse HEAD)"
  target="$(git -C "$folder" rev-parse refs/remotes/origin/main)"
  if [[ "$before" == "$target" ]]; then
    log "Актуально: ${name} (${before:0:10})"
    return 0
  fi
  if ! git -C "$folder" merge-base --is-ancestor "$before" "$target"; then
    log "ПРОПУСК: локальная ветка разошлась с GitHub. Нужна ручная проверка"
    FAILED=1
    return 0
  fi
  count="$(git -C "$folder" rev-list --count "${before}..${target}")"
  if git -C "$folder" merge --ff-only --quiet "$target"; then
    after="$(git -C "$folder" rev-parse HEAD)"
    log "ОБНОВЛЕНО: ${name}: ${before:0:10} -> ${after:0:10}, ${count} коммит(ов)"
    UPDATED=$((UPDATED + 1))
    notify "${name}: загружено ${count} новых коммитов"
  else
    log "ОШИБКА: fast-forward не удался; автоматическое слияние отменено"
    FAILED=1
  fi
}

log "=== Старт синхронизации навыков ==="
sync_one "historian-research" "${BASE}/historian-research"
sync_one "ex-ussr-kinship-research" "${BASE}/kinship/ex-ussr-kinship-research"
log "Готово: обновлено ${UPDATED}, ошибки/пропуски ${FAILED}"
if [[ "$FAILED" -ne 0 ]]; then
  notify "Проверь журнал обновлений: есть пропущенные репозитории"
  exit 1
fi
