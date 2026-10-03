# shellcheck shell=bash
# Helpers for pin-bumps.sh, with no network: reading and writing a Feature's
# pins.sh, checking upstream values before they're written, and the version,
# changelog and PR-body edits a bump makes. Sourced.

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
    { print }' "$1" >"$1.tmp" && cat "$1.tmp" >"$1" && rm -f "$1.tmp"
}

# Succeeds when an upstream value fits its pattern; nothing else is written.
valid() { # version|name|commit|sha256 value
  case $1 in
    version | name) [[ $2 =~ ^[A-Za-z0-9._+-]+$ ]] ;;
    commit) [[ $2 =~ ^[0-9a-f]{40}$ ]] ;;
    sha256) [[ $2 =~ ^[0-9a-f]{64}$ ]] ;;
    *) return 2 ;;
  esac
}

# Succeeds when version a is later than b; a leading v is ignored.
version_gt() { # a b
  local a=${1#v} b=${2#v}
  [ "$a" != "$b" ] && printf '%s\n%s\n' "$b" "$a" | sort -V -C
}

# Expands an asset-name template: {tag} is the tag, {version} the tag without
# its leading v (as the Features' onCreate.sh does).
expand_asset() { # template tag
  local name=${1//\{tag\}/$2}
  echo "${name//\{version\}/${2#v}}"
}

bump_minor() { # X.Y.Z
  local major minor
  IFS=. read -r major minor _ <<<"$1"
  echo "$major.$((minor + 1)).0"
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
    END { if (!done) entry() }' "$1" "$1" >"$1.tmp" \
    && cat "$1.tmp" >"$1" && rm -f "$1.tmp"
}

# A PR body's machine-read lines. "Excluded:" lists versions never to propose
# again; the hidden "held" line lists the versions the PR carries, which
# closing it unmerged excludes. Keys are tool@value.
key_ok() { [[ $1 =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._+-]+$ ]]; }

body_excluded() { # body
  local key
  sed -n 's/^Excluded: *//p' <<<"$1" | head -1 | tr -d '`' | tr ',' '\n' \
    | while read -r key; do if key_ok "$key"; then echo "$key"; fi; done
}

body_held() { # body
  local key
  sed -n 's/^<!-- pin-bumps held: \(.*\) -->$/\1/p' <<<"$1" | head -1 \
    | tr ' ' '\n' | while read -r key; do
    if key_ok "$key"; then echo "$key"; fi
  done
}
