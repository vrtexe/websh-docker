#!/usr/bin/env bash
# Smoke-test one image on the machine's own architecture:
#   ./test.sh <image> <tcl-version>          pure websh image
#   ./test.sh <image> <tcl-version> apache   -apache image: also serve test/hello.ws3 over HTTP
#   ENGINE=podman ./test.sh ...    PLATFORM=linux/amd64 ./test.sh ...   (another arch, emulated)
# Checks websh and Tcl versions, CPU, the websh package from tclsh, and a CGI request.
set -euo pipefail
cd "$(dirname "$0")"
image=$1 tcl=$2 kind=${3:-websh}
engine=${ENGINE:-docker}
websh=$(jq -r .websh.version versions.json)
case "${PLATFORM:-$(uname -m)}" in
	linux/amd64 | x86_64) platform=linux/amd64 machine=x86_64 ;;
	linux/arm64 | arm64 | aarch64) platform=linux/arm64 machine=aarch64 ;;
	*) echo "unsupported platform: ${PLATFORM:-$(uname -m)}" >&2; exit 1 ;;
esac
run() { "$engine" run --rm -i --platform "$platform" "$@"; }

# the websh interpreter
run --entrypoint websh "$image" /dev/stdin <<EOF
set got "[package present websh] [info patchlevel] \$tcl_platform(machine)"
if {\$got ne "$websh $tcl $machine"} { puts stderr "FAIL: \$got, want $websh $tcl $machine"; exit 1 }
foreach f {/usr/local/share/licenses/websh/LICENSE /usr/local/share/licenses/websh/NOTICE} {
	if {![file exists \$f]} { puts stderr "FAIL: \$f missing"; exit 1 }
}
EOF

# websh as a package in plain tclsh
got=$(echo 'puts [package require websh]' | run --entrypoint tclsh "$image" /dev/stdin)
[ "$got" = "$websh" ] || { echo "FAIL: package require websh gave '$got'" >&2; exit 1; }

# a CGI request, the way a web server runs websh
body=$(run -e GATEWAY_INTERFACE=CGI/1.1 -e REQUEST_METHOD=GET -e QUERY_STRING=name=websh \
	--entrypoint websh "$image" /dev/stdin <<'EOF'
web::command default { web::put "hello [web::param name]" }
web::dispatch
EOF
)
case "$body" in *"hello websh"*) ;; *) echo "FAIL: CGI output: $body" >&2; exit 1 ;; esac

if [ "$kind" = apache ]; then
	id=$("$engine" run -d --platform "$platform" -p 127.0.0.1::80 \
		-v "$PWD/test/hello.ws3:/var/www/html/hello.ws3:ro" "$image")
	trap '"$engine" rm -f "$id" > /dev/null' EXIT
	port=$("$engine" port "$id" 80 | head -1 | sed 's/.*://')
	body=""
	for _ in $(seq 1 30); do
		body=$(curl -fsS "http://127.0.0.1:$port/hello.ws3?name=apache" 2>/dev/null) && break
		sleep 1
	done
	case "$body" in *"hello apache from websh $websh"*) ;; *)
		echo "FAIL: HTTP: ${body:-no response}" >&2; "$engine" logs "$id" >&2; exit 1 ;; esac
fi

echo "ok $image ($kind): websh $websh, Tcl $tcl, $machine"
