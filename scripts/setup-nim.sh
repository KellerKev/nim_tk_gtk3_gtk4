#!/usr/bin/env bash
# One-time Nim bootstrap via the official choosenim installer.
# Safe to re-run — exits early if nim is already present.
set -euo pipefail

: "${NIM_HOME:?NIM_HOME must be set (pixi activation.env should provide it)}"

if [ -x "$NIM_HOME/bin/nim" ]; then
  echo "nim already installed at $NIM_HOME/bin/nim"
  "$NIM_HOME/bin/nim" --version | head -1
  exit 0
fi

mkdir -p "$NIM_HOME"
export CHOOSENIM_DIR="$NIM_HOME/.choosenim"
export CHOOSENIM_NO_ANALYTICS="${CHOOSENIM_NO_ANALYTICS:-1}"

INIT=/tmp/choosenim_init.sh
curl -fsSL https://nim-lang.org/choosenim/init.sh -o "$INIT"
sh "$INIT" -y

# choosenim's init installs the `choosenim` binary into ~/.nimble/bin and
# uses that to download/build the Nim toolchain (also into ~/.nimble/bin).
# Symlink so $NIM_HOME/bin resolves.
if [ -d "$HOME/.nimble/bin" ]; then
  ln -sfn "$HOME/.nimble/bin" "$NIM_HOME/bin"
fi

"$NIM_HOME/bin/nim" --version | head -1
