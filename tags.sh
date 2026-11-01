#!/usr/bin/env bash
# Print the tags for one Tcl version and variant:
#   ./tags.sh 8.6.18 alpine3.24  ->  3.6.0b5-tcl8.6.18-alpine ... 3.6-tcl8.6-alpine ... 3.6-alpine alpine
# websh version first (3.6.0b5 and 3.6), then the Tcl it is built on: the exact version, plus
# tcl8.6 / tcl8 when it is the newest of that minor / major. The newest Tcl overall also gets
# tags without a Tcl part (3.6-alpine, alpine). Debian slim is the default variant (no suffix,
# "latest"), since there is no full Debian variant here.
set -euo pipefail
cd "$(dirname "$0")"
tcl=$1 variant=$2

jq -r --arg tcl "$tcl" --arg var "$variant" '
	def vkey: split(".") | map(tonumber);
	(.tcl | sort_by(vkey)) as $all
	| ($tcl | split(".")) as $p
	| ($p[0:2] | join(".")) as $minor
	| $p[0] as $major
	| def newest(f): [$all[] | select(f)] | last == $tcl;
	  ("tcl" + $tcl) as $exact
	| ([$exact]
	   + (if newest(split(".")[0:2] | join(".") == $minor) then ["tcl" + $minor] else [] end)
	   + (if newest(split(".")[0] == $major) then ["tcl" + $major] else [] end)) as $tcls
	| .websh.version as $wv
	| [$wv, ($wv | split(".")[0:2] | join("."))] as $websh
	| (if $var == "slim-trixie" then ["", "-slim", "-slim-trixie"]
	   elif ($var | startswith("alpine")) then ["-alpine", "-\($var)"]
	   else ["-\($var)"] end) as $suffixes
	| [$websh[] as $w | $tcls[] as $t | $suffixes[] as $s | "\($w)-\($t)\($s)"]
	  + (if newest(true) then
	       [$websh[] as $w | $suffixes[] as $s | "\($w)\($s)"]
	       + [$suffixes[] | if . == "" then "latest" else ltrimstr("-") end]
	     else [] end)
	| join(" ")
' versions.json
