#!/bin/bash
cd "$(dirname "$0")"
stty raw -echo -isig 2>/dev/null
trap 'stty sane 2>/dev/null' EXIT
./el "${1:-dude}"
