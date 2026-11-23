#!/bin/bash
# Установка/удаление ежедневной синхронизации навыков в пользовательском launchd.
# Не требует sudo и не изменяет рабочие репозитории при установке.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYNC="${ROOT}/scripts/sync-macos.sh"
LABEL="local.history-skills-sync"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG="${HOME}/Library/Logs/history-skills-sync.log"
DOMAIN="gui/$(id -u)"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
  rm -f -- "$PLIST"
  printf 'Автосинхронизация выключена. Журнал оставлен: %s\n' "$LOG"
  exit 0
fi

if [[ "${1:-}" != "" ]]; then
  echo "Использование: bash scripts/install-macos-sync.sh [--uninstall]" >&2
  exit 2
fi
if [[ ! -f "$SYNC" ]]; then
  echo "Не найден основной скрипт: $SYNC" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Для создания launchd plist нужен python3." >&2
  exit 1
fi
if ! command -v launchctl >/dev/null 2>&1; then
  echo "Эта установка поддерживает только macOS (launchctl)." >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"
python3 - "$PLIST" "$SYNC" "$LOG" <<'PY'
import plistlib
import sys
from pathlib import Path
destination, script, logfile = (Path(x) for x in sys.argv[1:])
spec = {
    "Label": "local.history-skills-sync",
    "ProgramArguments": ["/bin/bash", str(script)],
    "RunAtLoad": True,
    "StartCalendarInterval": {"Hour": 11, "Minute": 20},
    "StandardOutPath": str(logfile),
    "StandardErrorPath": str(logfile),
}
with destination.open("wb") as file:
    plistlib.dump(spec, file, sort_keys=True)
PY

launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST"
printf 'Установлено: %s\n' "$PLIST"
printf 'Проверка каждый день в 11:20 по местному времени Mac; также при входе в систему.\n'
printf 'Журнал: %s\n' "$LOG"
printf 'Остановить: bash "%s" --uninstall\n' "${ROOT}/scripts/install-macos-sync.sh"
