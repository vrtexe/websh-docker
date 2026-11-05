#!/usr/bin/env bash
# Print the tags of one image: ./tags.sh <tcl-version> <variant>
# Short aliases go to the newest Tcl; slim is the default.
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
	   elif ($var | startswith("alpine")) then ["-\($var | sub("^alpine[0-9.]+"; "alpine"))", "-\($var)"]
	   else ["-\($var)"] end) as $suffixes
	| [$websh[] as $w | $tcls[] as $t | $suffixes[] as $s | "\($w)-\($t)\($s)"]
	  + (if newest(true) then
	       [$websh[] as $w | $suffixes[] as $s | "\($w)\($s)"]
	       + [$suffixes[] | if . == "" then "latest" else ltrimstr("-") end]
	     else [] end)
	| join(" ")
' versions.json
