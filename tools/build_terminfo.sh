#!/bin/bash

# This script builds iTerm2's modified terminfo files by starting with the
# system terminfo and adding definitions in Resources/xterm-terminfo-additions.
# This avoids compatibility problems with apps that expect the system terminfo,
# since who knows what version macOS ships with. You probably need to run this
# for each new major version of macos.
# TODO: Do this at runtime.

rm -rf Resources/terminfo
mkdir Resources/terminfo

# These are the terminfo entries that xterm defines intersected with what ships with macOS, minus those that would cause duplication.
terms=( "ansi+enq" "ansi+rep" "dec+sl" "vt220+keypad" "xterm" "xterm+256color" "xterm+app" "xterm+edit" "xterm+kbs" "xterm+pc+edit" "xterm+pcc0" "xterm+pcc1" "xterm+pcc2" "xterm+pcc3" "xterm+pce2" "xterm+pcf0" "xterm+pcf2" "xterm+pcfkeys" "xterm+sm+1006" "xterm+tmux" "xterm+vt+edit" "xterm+x11mouse" "xterm-16color" "xterm-256color" "xterm-88color" "xterm-8bit" "xterm-basic" "xterm-bold" "xterm-color" "xterm-hp" "xterm-new" "xterm-noapp" "xterm-old" "xterm-r5" "xterm-r6" "xterm-sco" "xterm-sun" "xterm-vt220" "xterm-vt52" "xterm-xf86-v44" "xterm-xfree86" "xterms")

# The xterm-direct family lives in modern ncurses but not in macOS's bundled
# terminfo. If Homebrew's ncurses is installed (`brew install ncurses`),
# regenerate Resources/xterm-direct-terminfo from there so it stays in sync
# with upstream. Otherwise the checked-in copy is used as-is.
direct_terms=( "xterm+direct" "xterm+direct16" "xterm+direct2" "xterm+direct256" "xterm+indirect" "xterm-direct" "xterm-direct16" "xterm-direct2" "xterm-direct256" )
HOMEBREW_NCURSES_INFOCMP=""
HOMEBREW_NCURSES_TIC=""
if command -v brew >/dev/null 2>&1; then
  if BREW_NCURSES_PREFIX="$(brew --prefix ncurses 2>/dev/null)" && [[ -x "$BREW_NCURSES_PREFIX/bin/infocmp" ]] && [[ -x "$BREW_NCURSES_PREFIX/bin/tic" ]]; then
    HOMEBREW_NCURSES_INFOCMP="$BREW_NCURSES_PREFIX/bin/infocmp"
    HOMEBREW_NCURSES_TIC="$BREW_NCURSES_PREFIX/bin/tic"
    echo "Found Homebrew ncurses; regenerating Resources/xterm-direct-terminfo from $HOMEBREW_NCURSES_INFOCMP"
  fi
fi

cat /dev/null > Resources/xterm-terminfo

# Iterate over the list
for term in "${terms[@]}"; do
  infocmp -x $term >> Resources/xterm-terminfo
  perl -pi -e 'chomp if eof' Resources/xterm-terminfo
  cat Resources/xterm-terminfo-additions >> Resources/xterm-terminfo
done

# Regenerate xterm-direct-terminfo if Homebrew ncurses is available;
# otherwise the checked-in copy (last produced by this same loop) is used.
if [[ -n "$HOMEBREW_NCURSES_INFOCMP" ]]; then
  cat /dev/null > Resources/xterm-direct-terminfo
  for term in "${direct_terms[@]}"; do
    "$HOMEBREW_NCURSES_INFOCMP" -x "$term" >> Resources/xterm-direct-terminfo
    perl -pi -e 'chomp if eof' Resources/xterm-direct-terminfo
    cat Resources/xterm-terminfo-additions >> Resources/xterm-direct-terminfo
  done
fi

unset TERMINFO_DIRS

/usr/bin/tic -x -o Resources/terminfo Resources/xterm-terminfo
/usr/bin/tic -x -o Resources/terminfo Resources/tmux-terminfo
if [[ -n "$HOMEBREW_NCURSES_TIC" ]]; then
  "$HOMEBREW_NCURSES_TIC" -x -o Resources/terminfo Resources/xterm-direct-terminfo
fi

export TERMINFO_DIRS=$(pwd)/Resources/terminfo
infocmp -x xterm-256color
