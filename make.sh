#!/bin/bash

if [ "$(stat -c %Y create.c)" != "$(cat create.c.timestamp 2>/dev/null)" ]; then
    stat -c %Y create.c > create.c.timestamp
    gcc create.c -o create
fi
./create
