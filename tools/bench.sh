#!/bin/bash
# Run the SprayApp web benchmark in headless Chrome.
#   bench.sh <url> <runs> <warm|cold> <label>
# Prints one JSON line per run. Needs the build served at <url>.
URL=$1; RUNS=${2:-5}; MODE=${3:-warm}; LABEL=${4:-run}
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK=${BENCH_TMP:-/tmp}/sprayapp-bench-$LABEL
rm -rf "$WORK"; mkdir -p "$WORK"
for i in $(seq 1 "$RUNS"); do
  PROFILE="$WORK/profile"
  [ "$MODE" = cold ] && PROFILE="$WORK/profile-$i"
  LOG="$WORK/log-$i.txt"
  "$CHROME" --headless=new --disable-gpu-sandbox --no-first-run --no-default-browser-check \
    --user-data-dir="$PROFILE" --window-size=390,844 --enable-logging=stderr --v=0 \
    --autoplay-policy=no-user-gesture-required "$URL" > "$LOG" 2>&1 &
  PID=$!
  for t in $(seq 1 120); do
    grep -q '\[bench\]' "$LOG" && break
    sleep 0.5
  done
  # Let Chrome write localStorage to disk, like a real visit that lasts a few seconds.
  if [ "$MODE" = warm ]; then sleep 8; else sleep 1; fi
  kill $PID 2>/dev/null; wait $PID 2>/dev/null
  LINE=$(grep -o '\[bench\] {[^}]*}' "$LOG" | head -1 | sed 's/\[bench\] //')
  echo "${LINE:-{\"error\":\"timeout\"\}}"
done
