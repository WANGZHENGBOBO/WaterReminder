#!/usr/bin/env bash
set -euo pipefail

shortcut_path="${1:?shortcut path required}"
shortcut_dump="$(plutil -p "$shortcut_path")"

for required in \
  '/喝水BO～/Sync' \
  'today-summary.json' \
  '喝水记录.csv' \
  'Devices' \
  '完成'; do
  grep -Fq "$required" <<<"$shortcut_dump"
done

if grep -Fq '查看今日记录' <<<"$shortcut_dump"; then
  echo "the old today view menu is still present" >&2
  exit 1
fi

if grep -Fq '/喝水BO～/Sync/iphone-amounts.txt' <<<"$shortcut_dump" || \
   grep -Fq '/喝水BO～/Sync/iphone-times.txt' <<<"$shortcut_dump"; then
  echo "legacy phone logs are still present" >&2
  exit 1
fi

python3 "$(dirname "$0")/validate_event_save.py" "$shortcut_path"
python3 "$(dirname "$0")/validate_lan_sync.py" "$shortcut_path"
python3 "$(dirname "$0")/validate_fast_feedback.py" "$shortcut_path"
python3 "$(dirname "$0")/validate_phone_entry.py" "$shortcut_path"

echo "PASS: Shortcut asks directly, accepts explicit Watch payloads, saves, and shows progress"
