#!/usr/bin/env bash
# One-time toolchain setup for this repo, on Ubuntu 24.04 (WSL2 or native).
# Installs Nix (single-user), OpenRAM (pinned commit + our patch), the SKY130 PDK and the SRAM cell library,
# then runs a short smoke test. Safe to re-run: every step skips itself if already done.
# Takes ~1-2 h on first run (mostly downloads). Needs ~15 GB disk and your sudo password once.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
OPENRAM_COMMIT=2f7b3866418ac1ce17ad959207a1489033d8c577   # OpenRAM 1.2.50, stable branch: the baseline was built with this
CONFIG=sky130_sram_1rw_8x16.py

step() { echo; echo "=== $* ==="; }

[ "$REPO" = "$HOME/sram_work" ] || { echo "ERROR: clone this repo to ~/sram_work (the scripts assume that path)."; exit 1; }

step "1/6 apt packages"
sudo apt-get update -qq
sudo apt-get install -y -qq git curl xz-utils make python3 python3-venv

step "2/6 Nix package manager (provides magic, netgen, ngspice, klayout at OpenRAM-tested versions)"
if [ ! -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
fi
mkdir -p ~/.config/nix
grep -qs flakes ~/.config/nix/nix.conf || echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
. "$HOME/.nix-profile/etc/profile.d/nix.sh"

step "3/6 OpenRAM at $OPENRAM_COMMIT + its Python venv"
[ -d ~/OpenRAM/.git ] || git clone https://github.com/VLSIDA/OpenRAM ~/OpenRAM
cd ~/OpenRAM
if [ "$(git rev-parse HEAD)" != "$OPENRAM_COMMIT" ]; then git fetch -q origin && git checkout -q "$OPENRAM_COMMIT"; fi
if git apply --reverse --check "$REPO/openram/sram_py_skip_characterization.patch" 2>/dev/null; then
  echo "patch already applied"
else
  git apply "$REPO/openram/sram_py_skip_characterization.patch" && echo "patch applied (compiler/sram.py)"
fi
cp "$REPO/openram/$CONFIG" macros/sram_configs/
# OpenRAM's Python deps live in ~/OpenRAM/.venv (system python3.12). The Nix shell's own venv (compiler/.venv) is empty.
if ! ~/OpenRAM/.venv/bin/python3 -c "import numpy, scipy, openram" 2>/dev/null; then
  python3 -m venv ~/OpenRAM/.venv
  ~/OpenRAM/.venv/bin/pip install -q -r "$REPO/openram/requirements-venv.txt"
  ~/OpenRAM/.venv/bin/pip install -q -e ~/OpenRAM
fi

step "4/6 environment variables in ~/.bashrc"
if ! grep -qs "OPENRAM_HOME" ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export OPENRAM_HOME="$HOME/OpenRAM/compiler"
export OPENRAM_TECH="$HOME/OpenRAM/technology"
export PDK_ROOT="$HOME/OpenRAM"
EOF
fi
export OPENRAM_HOME="$HOME/OpenRAM/compiler" OPENRAM_TECH="$HOME/OpenRAM/technology" PDK_ROOT="$HOME/OpenRAM"

step "5/6 SKY130 PDK + SRAM cell library (the first nix run also downloads the EDA tools)"
cd ~/OpenRAM
[ -d sky130A ] || "$REPO/nixrun" make sky130-pdk
[ -d technology/sky130/maglef_lib ] || "$REPO/nixrun" make sky130-install
"$REPO/nixrun" bash -c 'for t in magic netgen ngspice klayout; do printf "%-8s %s\n" "$t" "$(command -v $t || echo MISSING)"; done'

step "6/6 smoke test: extract the committed macro, then a short write/read test on the layout"
"$REPO/pex/extract.sh"
"$REPO/sim/prep_netlist.sh"
"$REPO/sim/run.sh" debug --netlist pex --glitch

echo
echo "Setup done. If the last line above says PASS, you are at the same point as the baseline."
echo "Open a NEW terminal (so ~/.bashrc is reloaded), then see README.md 'Everyday commands'."
