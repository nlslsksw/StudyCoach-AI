#!/bin/zsh
# App Store Connect befüllen – siehe tool/store.py --help
cd "$(dirname "$0")" && exec tool/.venv/bin/python tool/store.py "$@"
