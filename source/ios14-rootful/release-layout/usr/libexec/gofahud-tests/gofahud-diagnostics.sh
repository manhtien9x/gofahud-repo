#!/bin/sh
export PATH=/usr/bin:/bin:/usr/bin:/bin:/usr/sbin:/sbin
export TZ=Asia/Ho_Chi_Minh
folder=/var/mobile/Library/Logs
file="$folder/GofaHUD-diagnostics.log"
mkdir -p "$folder"
stamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
touch "$file"; chmod 0644 "$file"
printf '%s diagnostics-start pid=%s\n' "$(stamp)" "$$" >> "$file"
trap 'printf "%s diagnostics-stop pid=%s\n" "$(stamp)" "$$" >> "$file"; exit 0' TERM INT
while :; do
  size=$(wc -c < "$file")
  if [ "$size" -gt 4194304 ]; then mv -f "$file" "$file.1"; touch "$file"; chmod 0644 "$file"; fi
  {
    printf '\n%s snapshot\n' "$(stamp)"
    /usr/libexec/gofahud-tests/gofahud-native-speed-bridge --status
    ps -Ao pid,comm | grep -E 'SpringBoard|CarPlay|GOFA|gofahud' | grep -v grep
    for name in GofaHUD-phone.log GofaHUD-native-bridge.log GofaHUD-drive-recorder.log GofaHUD-carplay-open-result.json; do
      if [ -f "$folder/$name" ]; then printf '%s\n' "--- $name"; tail -n 3 "$folder/$name"; fi
    done
  } >> "$file" 2>&1
  sleep 10
done
