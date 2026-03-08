#!/usr/bin/env bash
set -euo pipefail

# 1. Ensure python3 and pip are available
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }
command -v pip3 >/dev/null 2>&1 || { echo "pip3 not found"; exit 1; }

# 2. Create and activate venv
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate

# 3. Upgrade pip and install requirements
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# 4. Ensure ~/.local/bin is on PATH for future shells
PROFILE_FILE="$HOME/.profile"
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"
  echo "Added ~/.local/bin to PATH in $PROFILE_FILE"
fi

# 5. Also add to ~/.bashrc for interactive shells if not present
BASHRC="$HOME/.bashrc"
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
fi

# 6. Source profile to update current shell (best effort)
# Note: this affects only the current shell if it's bash-compatible
# If using a different shell, restart or source the appropriate file.
source "$PROFILE_FILE" || true

echo "Virtual environment created at .venv and requirements installed."
echo "Activate it with: source .venv/bin/activate"
echo "If you installed packages with --user, scripts will be available in ~/.local/bin"
