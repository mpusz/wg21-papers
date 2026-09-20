#!/bin/bash
# Build the standardese wording for the quantities and units library.
#
#   ./build.sh          # set up dependencies and build
#   ./build.sh -s       # set up only
#   ./build.sh -d DIR   # keep the cloned dependencies in DIR
#
# Output: build/mp-units.html and build/mp-units.pdf
#
# This uses neither of the frameworks the papers in src/ use. It is the
# cxxdraft-htmlgen pipeline the C++ working draft itself is built with, which is
# why it needs LaTeX, Haskell and Node.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$HERE/.deps"
BUILD_DOCS=true

usage() {
    sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while getopts :hsd: opt; do
    case $opt in
        h) usage; exit 0 ;;
        s) BUILD_DOCS=false ;;
        d) DEPS_DIR="$OPTARG" ;;
        \?) echo "Error: invalid option -$OPTARG" >&2; usage; exit 1 ;;
        :)  echo "Error: option -$OPTARG requires an argument" >&2; exit 1 ;;
    esac
done

cat <<'PREREQ' >&2
Prerequisites (Debian/Ubuntu):

  sudo apt install latexmk texlive-latex-recommended texlive-latex-extra \
                   texlive-fonts-recommended lmodern \
                   haskell-stack graphviz nodejs npm ghc cabal-install
  npm install split mathjax-full mathjax-node-sre mathjax-node-cli yargs@16.2.0
  cabal update

and `node_modules/.bin` on PATH.

PREREQ

mkdir -p "$DEPS_DIR"

clone_if_missing() {
    local url="$1" branch="$2" target="$DEPS_DIR/$(basename "$1" .git)"
    if [ -d "$target" ]; then
        echo "Have $(basename "$target")"
        return
    fi
    echo "Cloning $(basename "$target")..."
    if [ "$branch" = "default" ]; then
        git clone "$url" --depth=1 "$target"
    else
        git clone "$url" --branch "$branch" --depth=1 "$target"
    fi
}

clone_if_missing "https://github.com/JohelEGP/jegp.cmake_modules.git" "default"
clone_if_missing "https://github.com/JohelEGP/draft.git" "standardese_sources_base"
clone_if_missing "https://github.com/JohelEGP/cxxdraft-htmlgen.git" "standardese_sources_base"

BUILD_DIR="$HERE/build"
cmake -S "$HERE" -B "$BUILD_DIR" \
      -DCMAKE_MODULE_PATH="$DEPS_DIR/jegp.cmake_modules/modules" \
      -DJEGP_STANDARDESE_SOURCES_GIT_REPOSITORY="$DEPS_DIR/draft" \
      -DJEGP_CXXDRAFT_HTMLGEN_GIT_REPOSITORY="$DEPS_DIR/cxxdraft-htmlgen"

if [ "$BUILD_DOCS" = true ]; then
    export LC_ALL=C.UTF-8 LANG=C.UTF-8
    cmake --build "$BUILD_DIR"
    echo "Built $BUILD_DIR/mp-units.html and $BUILD_DIR/mp-units.pdf"
else
    echo "Configured. Build with: cmake --build $BUILD_DIR"
fi
