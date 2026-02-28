#!/bin/bash

if [ ! -f ./tls/create.c ]; then
    echo -e "\e[31mERROR: create.c was not found.\e[0m"
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

if [ "$succes" = "0" ]; then
    ./tls/create
fi
