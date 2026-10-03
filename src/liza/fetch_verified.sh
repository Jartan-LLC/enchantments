# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/fetch_verified.sh, not a copy.

# Fetches into a destination only if the bytes match the expected digest.
fetch_verified() { # url expected-sha256 destination
  # --retry skips connection resets, and curl before 7.71 has no
  # --retry-all-errors to retry them.
  local retry_flags=(--retry 3 --retry-connrefused)
  if curl --retry-all-errors --version >/dev/null 2>&1; then
    retry_flags+=(--retry-all-errors)
  fi
  if curl -fsSL "${retry_flags[@]}" --retry-max-time 900 \
    --connect-timeout 15 --max-time 900 "$1" -o "$3.part" \
    && echo "$2  $3.part" | sha256sum --check --status; then
    mv -f "$3.part" "$3"
  else
    rm -f "$3.part"
    return 1
  fi
}
