#!/bin/sh
# Start script for Flowplan on Railway.
#  1. Works out APP_URL from the Railway domain when it is not set.
#  2. Sizes Node's heap, worker threads and OCR to the service's memory and CPU
#     (Railway shows the host's 32+ CPUs inside a small service).
#  3. On the first boot only: starts Flowplan on 127.0.0.1, creates the
#     administrator from ADMIN_EMAIL / ADMIN_PASSWORD, stops it again. The public
#     port opens only after that, so no visitor can claim the instance.
#  4. Hands over to the upstream entrypoint (exits non-zero when Flowplan dies,
#     so Railway's ON_FAILURE policy restarts it).
set -eu

DATA="${FLOWPLAN_DATA_DIR:-/app/data}"
export FLOWPLAN_DATA_DIR="$DATA"
PUBLIC_PORT="${PORT:-3000}"

log() { echo "railway-start: $*"; }

# ---- 1. APP_URL -------------------------------------------------------------
case "${APP_URL:-}" in
  http://?* | https://?*) ;;
  *)
    if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
      APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
    else
      echo "railway-start: APP_URL is empty and the service has no public domain. Add a domain (Settings → Networking) or set APP_URL." >&2
      exit 1
    fi
    ;;
esac
APP_URL="${APP_URL%/}"
export APP_URL
log "APP_URL=$APP_URL"

# ---- 2. Memory and CPU ------------------------------------------------------
mem_mb=0
mem_raw="$(cat /sys/fs/cgroup/memory.max 2> /dev/null || echo max)"
case "$mem_raw" in '' | max | *[!0-9]*) ;; *) mem_mb=$((mem_raw / 1048576)) ;; esac
cpus=0
if read -r quota period < /sys/fs/cgroup/cpu.max 2> /dev/null; then
  case "$quota" in '' | max | *[!0-9]*) ;; *) cpus=$(((quota + period - 1) / period)) ;; esac
fi
if [ "$cpus" -le 0 ]; then cpus="$(nproc 2> /dev/null || echo 2)"; fi
if [ "$cpus" -gt 8 ]; then cpus=8; fi
if [ "$cpus" -lt 1 ]; then cpus=1; fi

case "${NODE_OPTIONS:-}" in
  *max-old-space-size*) ;;
  *)
    if [ "$mem_mb" -gt 0 ]; then
      heap=$((mem_mb * 55 / 100))
      if [ "$heap" -lt 192 ]; then heap=192; fi
      NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--max-old-space-size=$heap"
      export NODE_OPTIONS
    fi
    ;;
esac
small=
if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 1500 ]; then small=1; fi
# Export/import worker threads: upstream starts cores-1 of them (31 on Railway).
if [ -z "${FLOWPLAN_WORKERS:-}" ]; then
  if [ -n "$small" ]; then FLOWPLAN_WORKERS=1; else FLOWPLAN_WORKERS=$((cpus > 1 ? cpus - 1 : 1)); fi
fi
# Text recognition for scanned PDFs (Tesseract) needs a few hundred MB per job.
if [ -z "${FLOWPLAN_OCR:-}" ] && [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 1000 ]; then
  FLOWPLAN_OCR=0
  log "OCR of scanned PDFs is off below 1 GB of memory (set FLOWPLAN_OCR=1 to force it on)."
fi
FLOWPLAN_PROCESSES="${FLOWPLAN_PROCESSES:-1}"
UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-$((cpus < 4 ? 4 : cpus))}"
VIPS_CONCURRENCY="${VIPS_CONCURRENCY:-$((cpus < 2 ? cpus : 2))}"
MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export FLOWPLAN_WORKERS FLOWPLAN_PROCESSES UV_THREADPOOL_SIZE VIPS_CONCURRENCY MALLOC_ARENA_MAX
[ -n "${FLOWPLAN_OCR:-}" ] && export FLOWPLAN_OCR
log "memory ${mem_mb:-?} MB, cpus $cpus, NODE_OPTIONS=${NODE_OPTIONS:-}, FLOWPLAN_WORKERS=$FLOWPLAN_WORKERS"

# ---- AI (optional) ----------------------------------------------------------
if [ -n "${FLOWPLAN_AI_API_KEY:-}" ]; then
  FLOWPLAN_AI="${FLOWPLAN_AI:-on}"
  FLOWPLAN_AI_PROVIDER="${FLOWPLAN_AI_PROVIDER:-openai}"
  export FLOWPLAN_AI FLOWPLAN_AI_PROVIDER
  log "AI on with provider $FLOWPLAN_AI_PROVIDER at ${FLOWPLAN_AI_BASE_URL:-its default address}."
fi

# ---- 3. First boot: create the administrator --------------------------------
# A setup token nobody knows: only this script can create the first account,
# even if something below fails.
if [ -z "${FLOWPLAN_SETUP_TOKEN:-}" ]; then
  FLOWPLAN_SETUP_TOKEN="$(node -e 'process.stdout.write(require("node:crypto").randomBytes(24).toString("hex"))')"
fi
export FLOWPLAN_SETUP_TOKEN

check=0
node /app/railway-bootstrap.mjs check || check=$?
if [ "$check" -gt 1 ]; then
  echo "railway-start: could not tell whether Flowplan is set up (exit $check); stopping so Railway retries." >&2
  exit 1
fi
if [ "$check" -eq 0 ]; then
  log "first boot: creating the administrator on a loopback-only instance."
  ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
  if [ -z "${ADMIN_EMAIL:-}" ] || [ "${#ADMIN_PASSWORD}" -lt 10 ]; then
    echo "railway-start: ADMIN_EMAIL and ADMIN_PASSWORD (10+ characters) are needed for the first boot." >&2
    exit 1
  fi
  BOOT_PORT=39123
  HOSTNAME=127.0.0.1 PORT=$BOOT_PORT /app/entrypoint.sh &
  boot_pid=$!
  rc=0
  BOOT_PORT=$BOOT_PORT node /app/railway-bootstrap.mjs create || rc=$?
  kill -TERM "$boot_pid" 2> /dev/null || true
  wait "$boot_pid" 2> /dev/null || true
  if [ "$rc" -ne 0 ]; then
    echo "railway-start: creating the administrator failed (exit $rc); stopping so Railway retries." >&2
    exit 1
  fi
  log "administrator created; starting Flowplan on port $PUBLIC_PORT."
fi

# ---- 4. Flowplan ------------------------------------------------------------
export HOSTNAME=0.0.0.0 PORT="$PUBLIC_PORT"
exec /app/entrypoint.sh
