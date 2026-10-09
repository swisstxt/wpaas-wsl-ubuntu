#!/bin/bash
# Exercises bin/wslview's routing in dry-run mode: no Windows host needed.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
W="$REPO_ROOT/bin/wslview"

fails=0
assert_eq()    { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3' got '$2'"; fails=$((fails+1)); fi; }
assert_match() { if grep -qE -- "$3" <<<"$2"; then echo "ok   $1"; else echo "FAIL $1: /$3/ not found in '$2'"; fails=$((fails+1)); fi; }

export WSLVIEW_DRY_RUN=1
export WSLVIEW_FIREFOX="$TMP/firefox.exe"
: > "$WSLVIEW_FIREFOX"

oauth='https://oauth-openshift.apps.stxt-dev-1.wm6w.p3.openshiftapps.com/oauth/authorize?client_id=x&redirect_uri=http%3A%2F%2Flocalhost'
assert_eq "openshiftapps oauth url goes to firefox"   "$("$W" "$oauth")"                                   "firefox	$oauth"
assert_eq "openshiftapps with port goes to firefox"   "$("$W" 'https://api.stxt-dev-1.wm6w.p3.openshiftapps.com:443/')" "firefox	https://api.stxt-dev-1.wm6w.p3.openshiftapps.com:443/"
assert_eq "bare openshiftapps.com goes to firefox"    "$("$W" 'http://openshiftapps.com')"                 "firefox	http://openshiftapps.com"
assert_eq "userinfo is ignored when matching"         "$("$W" 'https://u:p@console.openshiftapps.com/x')" "firefox	https://u:p@console.openshiftapps.com/x"
assert_eq "lookalike suffix stays on default"         "$("$W" 'https://openshiftapps.com.evil.example/')"  "default	https://openshiftapps.com.evil.example/"
assert_eq "substring without dot stays on default"    "$("$W" 'https://notopenshiftapps.com/')"            "default	https://notopenshiftapps.com/"
assert_eq "domain in path stays on default"           "$("$W" 'https://login.microsoftonline.com/openshiftapps.com')" "default	https://login.microsoftonline.com/openshiftapps.com"
assert_eq "microsoft login goes to default"           "$("$W" 'https://login.microsoftonline.com/common/oauth2')" "default	https://login.microsoftonline.com/common/oauth2"
assert_eq "mailto goes to default"                    "$("$W" 'mailto:someone@openshiftapps.com')"         "default	mailto:someone@openshiftapps.com"

touch "$TMP/file.txt"
if command -v wslpath >/dev/null; then
  assert_match "local path is converted to a windows path" "$("$W" "$TMP/file.txt")" '^default	\\\\wsl'
else
  echo "skip local path conversion (no wslpath)"
fi
assert_eq "unknown non-path string passes through" "$("$W" 'ftp://example.org/f')" "default	ftp://example.org/f"

# Loopback URLs: a CLI tool's local callback server that redirects to the real
# login page. The wrapper must route on the redirect target but open the
# original URL, and it must ignore proxy variables for the local request.
start_redirector() { # start_redirector <location>: listens on 127.0.0.1, sets $port
  rm -f "$TMP/port"
  python3 -I - "$1" "$TMP/port" >/dev/null 2>&1 <<'PY' &
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(302); self.send_header("Location", sys.argv[1]); self.end_headers()
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[2], "w").write(str(srv.server_address[1]))
srv.serve_forever()
PY
  redirector_pid=$!
  for _ in $(seq 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
  port=$(cat "$TMP/port")
}
stop_redirector() { kill "$redirector_pid" 2>/dev/null; wait "$redirector_pid" 2>/dev/null; }

start_redirector "$oauth"
assert_eq "loopback redirecting to openshiftapps goes to firefox"  "$("$W" "http://127.0.0.1:$port/")" "firefox	http://127.0.0.1:$port/"
assert_eq "localhost name form is also peeked"                     "$("$W" "http://localhost:$port/")" "firefox	http://localhost:$port/"
assert_eq "proxy variables do not break the local peek" \
  "$(HTTPS_PROXY=socks5://localhost:1080 http_proxy=socks5://localhost:1080 "$W" "http://127.0.0.1:$port/")" "firefox	http://127.0.0.1:$port/"
stop_redirector
start_redirector 'https://login.microsoftonline.com/common/oauth2'
assert_eq "loopback redirecting elsewhere goes to default"         "$("$W" "http://127.0.0.1:$port/")" "default	http://127.0.0.1:$port/"
stop_redirector
assert_eq "loopback with nothing listening goes to default"        "$("$W" "http://127.0.0.1:$port/")" "default	http://127.0.0.1:$port/"
assert_eq "ipv6 loopback host is parsed"                           "$("$W" 'http://[::1]:1/')" "default	http://[::1]:1/"
assert_eq "remote http url is not fetched"                         "$("$W" 'http://10.255.255.1:9/')" "default	http://10.255.255.1:9/"

rm -f "$WSLVIEW_FIREFOX"
out=$("$W" "$oauth" 2>"$TMP/err")
assert_eq    "missing firefox falls back to default" "$out" "default	$oauth"
assert_match "missing firefox warns on stderr"       "$(cat "$TMP/err")" 'firefox'

"$W" >/dev/null 2>&1; assert_eq "no argument exits 2" "$?" "2"
"$W" a b >/dev/null 2>&1; assert_eq "two arguments exit 2" "$?" "2"

[ "$fails" -eq 0 ] && echo "wslview test OK" || { echo "$fails failure(s)"; exit 1; }
