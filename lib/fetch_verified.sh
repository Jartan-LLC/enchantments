# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/fetch_verified.sh, not a copy.

# Fetches into a destination only if the bytes match the expected digest.
fetch_verified() { # url expected-sha256 destination
  if curl -fsSL --connect-timeout 15 --max-time 900 "$1" -o "$3.part" \
    && echo "$2  $3.part" | sha256sum --check --status; then
    mv -f "$3.part" "$3"
  else
    rm -f "$3.part"
    return 1
  fi
}
