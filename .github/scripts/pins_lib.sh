# shellcheck shell=bash
# Helpers for pin-bumps.sh, with no network: reading and writing a Feature's
# pins.sh, checking upstream values before they're written, the version and
# changelog edits a bump makes, and the PR body's machine-read lines. Sourced.

# --- pins.sh ------------------------------------------------------------------

# Prints "<kind> <tool>" for each "# pin <kind> <tool> ..." header, in order.
pin_list() { # file
  awk '$1 == "#" && $2 == "pin" && NF >= 4 { print $3, $4 }' "$1"
}

# Prints the value of the header attribute key (key=value) of tool's pin.
pin_attr() { # file tool key
  awk -v tool="$2" -v key="$3" '
    $1 == "#" && $2 == "pin" && $4 == tool {
      for (i = 5; i <= NF; i++)
        if (index($i, key "=") == 1) {
          print substr($i, length(key) + 2)
          found = 1
        }
    }
    END { exit !found }' "$1"
}

# Prints the NAME=value lines under tool's header, up to the next blank line
# or header. The file is parsed, never sourced.
pin_vars() { # file tool
  awk -v tool="$2" '
    $1 == "#" && $2 == "pin" { inside = ($4 == tool); next }
    !NF { inside = 0; next }
    inside && /^[A-Z0-9_]+=\x27[^\x27]*\x27$/ {
      eq = index($0, "=")
      print substr($0, 1, eq - 1) "=" substr($0, eq + 2, length($0) - eq - 2)
    }' "$1"
}

# Prints the value of NAME in the file, empty when it's absent.
pin_get() { # file name
  sed -n "s/^$2='\\([^']*\\)'\$/\\1/p" "$1"
}

# Replaces a file's content with stdin, keeping the file's mode.
overwrite() { # file
  local tmp
  tmp=$(mktemp) && cat >"$tmp" && cat "$tmp" >"$1" && rm -f "$tmp"
}

# Sets NAME's single-quoted value. Fails unless NAME is set exactly once and
# the value holds no quote or newline; callers check values with valid first.
pin_set() { # file name value
  [ "$(grep -c "^$2='[^']*'\$" "$1")" = 1 ] || return 1
  case $3 in *"'"* | *$'\n'*) return 1 ;; esac
  NAME=$2 VALUE=$3 awk '
    index($0, ENVIRON["NAME"] "=\x27") == 1 {
      print ENVIRON["NAME"] "=\x27" ENVIRON["VALUE"] "\x27"
      next
    }
    { print }' "$1" | overwrite "$1"
}

# --- Upstream values ----------------------------------------------------------

# Succeeds when an upstream value fits its pattern; nothing else is written.
valid() { # version|name|commit|sha256 value
  case $1 in
    version | name) [[ $2 =~ ^[A-Za-z0-9._+-]+$ ]] ;;
    commit) [[ $2 =~ ^[0-9a-f]{40}$ ]] ;;
    sha256) [[ $2 =~ ^[0-9a-f]{64}$ ]] ;;
    *) return 2 ;;
  esac
}

# Succeeds for a release version: dot-separated numbers, with an optional
# leading v. An rc, nightly or other label never counts as a release.
numeric_version() { [[ $1 =~ ^v?[0-9]+(\.[0-9]+)+$ ]]; }

# Prints a version that sort -V orders as PEP 440 does: a leading v goes,
# and a pre-release (a, b, rc) or dev release is marked to sort before its
# release, which "~" does for sort -V.
version_key() { # version
  sed -E -e 's/^v//' -e 's/([0-9])[.-]?(dev)/\1~~\2/' \
    -e 's/([0-9])[.-]?(a|alpha|b|beta|c|rc|pre|preview)([0-9])/\1~\2\3/' \
    <<<"$1"
}

# Succeeds when version a is later than b.
version_gt() { # a b
  local a b
  a=$(version_key "$1")
  b=$(version_key "$2")
  [ "$a" != "$b" ] && printf '%s\n%s\n' "$b" "$a" | sort -V -C
}

# Expands an asset-name template: {tag} is the tag, {version} the tag without
# its leading v (as the Features' onCreate.sh does).
expand_asset() { # template tag
  local name=${1//\{tag\}/$2}
  echo "${name//\{version\}/${2#v}}"
}

# --- Version and changelog ----------------------------------------------------

bump_minor() { # X.Y.Z
  local major minor
  IFS=. read -r major minor _ <<<"$1"
  echo "$major.$((minor + 1)).0"
}

set_version() { # devcontainer-feature.json version
  jq --arg v "$2" '.version = $v' "$1" | overwrite "$1"
}

# Adds a "## <version>" entry holding the lines in entry_file, then any lines
# from "## Unreleased", whose section it removes.
add_changelog_entry() { # file version entry_file
  awk -v version="$2" -v entry_file="$3" '
    function entry() {
      print "## " version
      print ""
      while ((getline line < entry_file) > 0) print line
      for (i = 1; i <= n; i++) print moved[i]
      print ""
      done = 1
    }
    NR == FNR {
      if ($0 == "## Unreleased") { unreleased = 1; next }
      if (/^## /) unreleased = 0
      if (unreleased && NF) moved[++n] = $0
      next
    }
    $0 == "## Unreleased" { skip = 1; next }
    /^## / { skip = 0; if (!done) entry() }
    skip { next }
    { print }
    END { if (!done) entry() }' "$1" "$1" | overwrite "$1"
}

# --- PR body lines ------------------------------------------------------------
# "Excluded:" lists versions never to propose again; the hidden "held" line
# lists the versions the PR carries, which closing it unmerged excludes;
# "Not applied:" lists newer versions a hand-edited branch doesn't carry.
# Keys are tool@value. A body edited on GitHub may have CRLF line endings.

key_ok() { [[ $1 =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._+-]+$ ]]; }

# Prints keys as "`a`, `b`", or "none".
key_list() { # keys...
  [ "$#" -gt 0 ] || { echo none && return 0; }
  # shellcheck disable=SC2016 # the backticks are Markdown
  printf '`%s`, ' "$@" | sed 's/, $//'
}

excluded_line() { echo "Excluded: $(key_list "$@")"; }
closed_line() { echo "Closed: nothing newer."; }
held_line() { echo "<!-- pin-bumps held: $* -->"; }
not_applied_line() { # keys...
  echo "Not applied: $(key_list "$@"), since this branch has commits from" \
    "someone else."
}

# Prints the body with CRLF line endings made LF.
body_lf() { tr -d '\r' <<<"$1"; }

body_excluded() { # body
  local key
  body_lf "$1" | sed -n 's/^Excluded: *//p' | sed -n 1p | tr -d '`' \
    | tr ',' '\n' | while read -r key; do
    if key_ok "$key"; then echo "$key"; fi
  done
}

body_held() { # body
  local key
  body_lf "$1" | sed -n 's/^<!-- pin-bumps held: \(.*\) -->$/\1/p' | sed -n 1p \
    | tr ' ' '\n' | while read -r key; do
    if key_ok "$key"; then echo "$key"; fi
  done
}

# Prints the body without its Not applied line.
body_without_not_applied() { # body
  body_lf "$1" | grep -v '^Not applied: ' || true
}

# Prints the body without its held and Not applied lines.
body_without_markers() { # body
  body_lf "$1" | grep -v -e '^<!-- pin-bumps held: ' -e '^Not applied: ' \
    || true
}
