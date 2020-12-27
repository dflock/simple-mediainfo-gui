#!/usr/bin/env bash

# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset   # Using an undefined variable is fatal
set -o errexit   # A sub-process/shell returning non-zero is fatal
# set -o pipefail  # If a pipeline step fails, the pipelines RC is the RC of the failed step
# set -o xtrace    # Output a complete trace of all bash actions; uncomment for debugging

# IFS=$'\n\t'  # Only split strings on newlines & tabs, not spaces.

usage() {
  cat <<EOF

A simple GUI for MediaInfo

USAGE
  $(basename "${BASH_SOURCE[0]}") FILE

ARGUMENTS
  FILE             Media file to show info for
  help             show this help

OPTIONS
  -h, --help       show this help

EXAMPLES
  $ $(basename "${BASH_SOURCE[0]}") FILE
EOF
  exit
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  rm -f $tmpfile
  exit "$code"
}

if ! command -v yad &> /dev/null
then
  die "yad could not be found\n\
    ${BASH_SOURCE[0]} requires yad (tested with 0.40.0 (GTK+ 3.24.20))\n\
    See: https://sourceforge.net/projects/yad-dialog/" 127
fi

if [[ $# == 0 ]]; then
  msg "Missing parameter: Media file name."
  usage
fi

if [[ $1 == '-h' || $1 == '--help' || $1 == 'help' ]]; then
  usage
fi

# Create temp files & setup cleanup
tmpfile=$(mktemp --tmpdir "$(basename "${BASH_SOURCE[0]}")-XXXXXX")
# We're going to use csplit
trap "{ rm -f "$tmpfile" "$tmpfile.00" "$tmpfile.01"; }" EXIT

# Run mediainfo and save output to tmp files
mediainfo "$1" | tr -s ' ' | awk -F' : ' '{print $1"\n"$2}' | csplit --quiet --prefix="$tmpfile." - '/^Audio$/'
# Trim first two blank lines from files
sed -i -e1,2d "$tmpfile.00"
sed -i -e1,2d "$tmpfile.01"

#
# Create dialog to display results
#
key="9s7dfjs" # yad shared memory key to link all these yads together
# Create yad tab for General list
yad --plug=$key --tabnum=1 --list --column="Key" --column="Value" \
    < "$tmpfile.00" &> /dev/null &
# Create yad tab for Audio list
yad --plug=$key --tabnum=2 --list --column="Key" --column="Value" \
    < "$tmpfile.01" &> /dev/null &
# Display both lists in tabbed dialog
yad --notebook --key=$key --tab="General" --tab="Audio" \
    --width=850 --height=800 --title="$(basename "$1") - Mediainfo" \
    --button=gtk-close:0 --dialog-sep --escape-ok \
    --window-icon="applications-multimedia"

