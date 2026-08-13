#!/usr/bin/env bash
# All modules rendered in ONE YARD registry so cross-module type links resolve
# (e.g. S3's `encryption_key : KMS::IKey` links to AWSCDK/KMS/IKey.html). YARD only
# linkifies types present in its registry at render time, so the whole library has to be
# a single `yard doc` run — per-module builds leave those refs as plain text. Output tree
# is <RootModule>/<Module>/<Class>.html (+ shared css/js). Built with the gem lib as CWD so
# "Defined in" paths render clean ("dynamo_db/table.rb"). Finally the theme is applied.
#
# Set PER_MODULE=1 to fall back to isolated per-module builds: crash-safe (each module in
# its own process), but cross-module links won't resolve. Kept as a safety valve.
#
#   build-module-docs.sh <gem-lib-dir> <out-dir> [module ...]   (no args = all)
set -euo pipefail
GEM_LIB="$(cd "$1" && pwd)"; OUT="$(mkdir -p "$2" && cd "$2" && pwd)"; shift 2
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"

# YARD's parser/registry recurse deeply on the big modules (interfaces is ~3.3k files)
# and SystemStackError. BOTH raises below are required — neither alone is enough
# (verified on `interfaces`): they clear two different limits hit at two different phases.
# Raise only the C/machine stack and it still dies in the registry resolver
# (YARD::Registry.at) when the VM frame stack fills; raise only the VM stack and it dies
# in the parser (ruby_parser Array.new) when the C stack fills. Set both. Best-effort.
ulimit -s unlimited 2>/dev/null || ulimit -s 1048576 2>/dev/null || true
export RUBY_THREAD_VM_STACK_SIZE="${RUBY_THREAD_VM_STACK_SIZE:-536870912}"

# jsii docs (and the module READMEs) are CommonMark. Render with redcarpet: it handles
# fenced ```ruby blocks *and* YARD then applies its own highlighter to them, so README
# examples get the same token markup as inline @example blocks. (kramdown's default mode
# doesn't recognise ``` fences; its GFM mode uses a different, unthemed highlighter.)
MARKUP=(--markup markdown --markup-provider redcarpet)

# Optional: another library's sources, so YARD resolves references into it
# properly rather than leaving them as text. YARD would then link them
# relatively, assuming one output tree; the plugin rewrites those addresses to
# the other library's published pages, so the trees stay independent.
#
#   CROSSLINK_LIBS="/path/to/lib/cdk8s /path/to/lib/constructs"
#   YARD_CROSSLINK="CDK8s=2.70.91,Constructs=10.8.1"
#
# The foreign pages YARD also generates are removed afterwards: they are a
# by-product of having the sources in the registry, and publishing them would
# put a second, unversioned copy of another library inside this tree.
CROSSLINK=()
if [ -n "${YARD_CROSSLINK:-}" ] && [ -n "${CROSSLINK_LIBS:-}" ]; then
  # Absolute: yard runs from inside $GEM_LIB, so a relative path here silently
  # resolves to nothing, yard is handed a directory that does not exist, and the
  # build succeeds having linked precisely nothing. Fail instead.
  for lib in ${CROSSLINK_LIBS}; do
    case "$lib" in
      /*) [ -d "$lib" ] || { echo "::error::CROSSLINK_LIBS: no such directory $lib"; exit 1; } ;;
      *)  echo "::error::CROSSLINK_LIBS must be absolute paths (got '$lib'); yard runs from inside $GEM_LIB"; exit 1 ;;
    esac
  done
  CROSSLINK=(-e "$SELF_DIR/yard-crosslink-plugin.rb")
  echo "crosslinking against: $YARD_CROSSLINK"
fi

modules=("$@")
[ ${#modules[@]} -eq 0 ] && modules=($(ls "$GEM_LIB"))
# No `mkdir` for the root module: YARD creates the directories from the module
# names in the source it is given, and pre-creating one named for a particular
# library left an empty AWSCDK/ beside every other library's real tree — enough
# to make the root ambiguous for every script that detects it from the tree.
cd "$GEM_LIB"

# Keep only real module dirs (relative names, so "Defined in" paths stay clean).
mods=()
for mod in "${modules[@]}"; do
  [ -d "$GEM_LIB/$mod" ] && mods+=("$mod") || echo "skip $mod (no dir)"
done

# A library with no submodules is flat: every type sits at the root and there
# are no per-module directories at all (cdk8s is like this; aws-cdk-lib, with
# its ~340 submodules, is not). That is a shape to build, not an empty build —
# the root files below are the whole library.
if [ ${#mods[@]} -eq 0 ]; then
  if [ -z "$(find "$GEM_LIB" -maxdepth 1 -name '*.rb' -print -quit)" ]; then
    echo "no modules and no root types to build"; exit 0
  fi
  echo "flat library: no submodules, building its root types"
fi

if [ "${PER_MODULE:-0}" = 1 ]; then
  # Fallback: isolated per-module builds. Crash-safe, but cross-module links stay plain.
  for mod in "${mods[@]}"; do
    tmp=$(mktemp -d)
    mapfile -t files < <(find "$mod" -name '*.rb')   # relative paths -> clean "Defined in"
    if [ ${#files[@]} -gt 0 ]; then
      printf 'yard %-22s %s files\n' "$mod" "${#files[@]}"
      if yard doc "${files[@]}" -o "$tmp" --no-cache --no-progress -q "${MARKUP[@]}" 2>/dev/null; then
        cp -r "$tmp/." "$OUT/"   # merge: AWSCDK/<Module>/ accumulates; css/js last-wins
      else
        echo "  (yard failed for $mod)"
      fi
    fi
    rm -rf "$tmp"
  done
else
  # Unified: one registry over the whole library so cross-module type links resolve.
  # Pass module dirs (YARD recurses for *.rb); a single invocation = a single registry.
  # Also pass the top-level *.rb files — the AWSCDK root module's core types (Stack,
  # App, IResolvable, Duration, RemovalPolicy, ...). They aren't under any submodule
  # dir, so a dirs-only run would drop them *and* leave every reference to them
  # unlinked (they're referenced everywhere). Skip the root _readme.rb (the package
  # README; the site's own landing is the intro).
  mapfile -t rootfiles < <(find . -maxdepth 1 -name '*.rb' ! -name '_readme.rb')
  total=$([ ${#mods[@]} -eq 0 ] && echo 0 || find "${mods[@]}" -name '*.rb' | wc -l)
  printf 'yard (unified) %s modules + %s root types, %s files -> one registry\n' \
    "${#mods[@]}" "${#rootfiles[@]}" "$((total + ${#rootfiles[@]}))"
  yard doc ${mods[@]+"${mods[@]}"} "${rootfiles[@]}" ${CROSSLINK_LIBS:-} \
    -o "$OUT" --no-cache --no-progress -q "${MARKUP[@]}" ${CROSSLINK[@]+"${CROSSLINK[@]}"}
fi

# Drop the foreign trees. They were built only so YARD could resolve into them,
# and the links point at their published homes rather than here.
if [ -n "${YARD_CROSSLINK:-}" ]; then
  for pair in ${YARD_CROSSLINK//,/ }; do
    foreign="${pair%%=*}"
    [ -d "$OUT/$foreign" ] && rm -rf "$OUT/$foreign" "$OUT/$foreign.html" \
      && echo "  removed the by-product $foreign/ tree"
  done
fi

# Apply the theme: YARD loads common.css last, so this overrides style.css site-wide.
if [ -f "$SELF_DIR/docs-theme.css" ] && [ -d "$OUT/css" ]; then
  cp "$SELF_DIR/docs-theme.css" "$OUT/css/common.css"
  echo "applied theme -> css/common.css"
fi
