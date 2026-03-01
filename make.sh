#!/bin/bash

if [ ! -f ./tls/create.c ]; then
    echo -e "\e[31mERROR: create.c was not found.\e[0m"
    exit 1
fi

if [ ! -f ./src/bash/bash.asm ]; then
    echo -e "\e[31mERROR: bash.asm was not found.\e[0m"
    exit 1
fi


if [ "$(stat -c %Y tls/create.c)" != "$(cat tls/create.c.timestamp 2>/dev/null)" ]; then
    gcc tls/create.c -o tls/create
    succes=$?
    
    echo $succes > tls/create.c.succes
    stat -c %Y tls/create.c > tls/create.c.timestamp
else
    succes=$(cat tls/create.c.succes 2>/dev/null)
fi

if [ "$(stat -c %Y src/bash/bash.asm)" != "$(cat tls/bash.asm.timestamp 2>/dev/null)" ]; then
    nasm src/bash/bash.asm -o bin/bash.img
    
    stat -c %Y src/bash/bash.asm > tls/bash.asm.timestamp
fi

if [ "$succes" = "0" ]; then
    ./tls/create
    truncate -s %512 bin/app_header
    cat bin/app_header >> bin/bash.img
fi
