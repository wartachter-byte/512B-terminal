#!/bin/bash

# 1. Bootloader/Bash build
if [ "$(cat tls/main.asm.timestamp)" != "$(stat -c %Y src/terminal/main.asm)" ]; then
	nasm src/terminal/main.asm -o bin/terminal.img
	stat -c %Y src/terminal/main.asm > tls/main.asm.timestamp
fi
# 2. Python3
python3 tls/create.py

# 3. Append command trie/app header (2 sectors) to the boot image if present
if [ -f bin/apps/app_header ]; then
	cat bin/apps/app_header >> bin/terminal.img
fi
