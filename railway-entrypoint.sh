#!/bin/sh
# Maps Railway onto FileBrowser Quantum:
# - listens on $PORT; files (/data/files), the database and an optional own config all
#   live on the /data volume, owned by the image's uid 1000;
# - FILEBROWSER_ADMIN_PASSWORD (a template secret) is read by upstream itself and resets
#   the admin's password on every start, so changing the variable and redeploying is the
#   password reset;
# - client IPs for login rate limits and lockouts come from Railway's edge, not the
#   shared edge address;
# - /data/config.yaml, if you create one, replaces the generated config entirely;
# - if the server exits within 60 s of starting (a bad variable or config), a notice page
#   is served instead of a crash loop. Later exits pass through so Railway restarts it.
set -u
log() { echo "[railway] $*"; }

DATA=/data
mkdir -p "$DATA/files"
# Railway mounts volumes root-owned; upstream runs as 1000:1000.
find "$DATA" -xdev ! -user 1000 -exec chown 1000:1000 {} + 2>/dev/null

PORT="${PORT:-8080}"
case "$PORT" in '' | *[!0-9]*) log "PORT=$PORT is not a number, using 8080"; PORT=8080 ;; esac

# The image's ENV points the database at /home/filebrowser/data, which is not the volume.
case "${FILEBROWSER_DATABASE_PATH:-}" in
  '' | /home/filebrowser/data/database.sqlite) export FILEBROWSER_DATABASE_PATH="$DATA/database.sqlite" ;;
esac

if [ -s "$DATA/config.yaml" ]; then
  export FILEBROWSER_CONFIG="$DATA/config.yaml"
  log "using your own config at $FILEBROWSER_CONFIG (the template's settings are not applied)"
else
  user="${FILEBROWSER_ADMIN_USERNAME:-admin}"
  case "$user" in
    '' | *[!A-Za-z0-9._@-]*) log "FILEBROWSER_ADMIN_USERNAME may only use letters, digits and . _ @ -, using admin"; user=admin ;;
  esac
  url="${FILEBROWSER_EXTERNAL_URL:-}"
  [ -z "$url" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && url="https://$RAILWAY_PUBLIC_DOMAIN"
  case "$url" in
    '' | http://* | https://*) ;;
    *) log "FILEBROWSER_EXTERNAL_URL must start with https://, ignoring it"; url="" ;;
  esac
  url="${url%/}"
  case "$url" in *[\"\\]*) url="" ;; esac
  mkdir -p /tmp/railway
  cat > /tmp/railway/config.yaml <<EOF
http:
  port: $PORT
  baseURL: "/"
  externalUrl: "$url"
  # Requests reach the service through Railway's edge, which rewrites X-Forwarded-For
  # with the visitor first (a spoofed value is dropped) and adds its own hops from
  # changing public addresses. Trusting every hop makes FileBrowser take the leftmost
  # entry, the visitor, so rate limits and lockouts are per visitor, not per edge.
  trustProxyHeaders: true
  trustedProxies:
    - "0.0.0.0/0"
    - "::/0"
server:
  cacheDir: "/tmp/filebrowser-cache"
  numImageProcessors: 2
  logging:
    - levels: "info|warning|error"
  sources:
    - path: "$DATA/files"
      name: "files"
auth:
  methods:
    password:
      enabled: true
      adminUsername: "$user"
      minLength: 8
      signup: false
EOF
  chown -R 1000:1000 /tmp/railway
  export FILEBROWSER_CONFIG=/tmp/railway/config.yaml
fi

if [ -z "${FILEBROWSER_ADMIN_PASSWORD:-}" ]; then
  unset FILEBROWSER_ADMIN_PASSWORD
  log "FILEBROWSER_ADMIN_PASSWORD is empty: on the first boot FileBrowser prints a one-time admin password below and asks you to change it at first login."
fi

# Railway counts the kernel's cache of files read or written as the service's memory and
# never frees it without memory pressure; drop it for the volume every 15 minutes.
( while sleep 900; do nice -n 19 sh /usr/local/bin/drop-file-cache.sh "$DATA" /tmp; done ) &
trimmer=$!

notice() {
  kill "$trimmer" 2>/dev/null
  dir=/tmp/notice
  mkdir -p "$dir/api"
  echo '{"message":"ok"}' > "$dir/api/health"
  cat > "$dir/index.html" <<EOF
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>FileBrowser is not running</title>
<body style="font:16px/1.5 system-ui,sans-serif;max-width:40em;margin:4em auto;padding:0 1em">
<h1>FileBrowser is not running</h1>
<p>The server stopped right after starting ($1). Open this service's <b>Deploy Logs</b> on Railway:
the lines above "[railway] showing a notice page" say what to fix (a variable, or your own
/data/config.yaml). Fix it, then redeploy. Your files on the volume are untouched.</p>
</body>
EOF
  log "showing a notice page on port $PORT until the problem is fixed"
  exec httpd -f -p "0.0.0.0:$PORT" -h "$dir"
}

started=$(date +%s)
su-exec 1000:1000 /home/filebrowser/filebrowser &
pid=$!
stopping=
trap 'stopping=1; kill -TERM "$pid" 2>/dev/null' TERM INT
wait "$pid"; rc=$?
# wait returns early when the trap fires; wait again for the real exit status.
while kill -0 "$pid" 2>/dev/null; do wait "$pid"; rc=$?; done
[ -n "$stopping" ] && { kill "$trimmer" 2>/dev/null; exit "$rc"; }
if [ $(( $(date +%s) - started )) -lt 60 ]; then
  notice "exit code $rc"
fi
kill "$trimmer" 2>/dev/null
exit "$rc"
