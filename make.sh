#!/bin/bash

# 1. Bootloader/Bash build
nasm src/bash/bash.asm -o bin/bash.img

# 2. Compileer Apps en verzamel offsets
# We reserveren sector 1-2 (1024 bytes) voor de app_header. Apps starten op sector 3.
CURRENT_SECTOR=3
OFFSETS_FILE="./tls/app_offsets.txt"
> $OFFSETS_FILE # Maak leeg

for app_src in ./src/apps/*; do
    [ -e "$app_src" ] || continue
    app_name=$(basename "$app_src")
    
    # Assembleer app
    nasm "$app_src" -o "bin/$app_name.bin"
    
    # Sla offset op voor create.c: "appname:sector"
    echo "$app_name:$CURRENT_SECTOR" >> $OFFSETS_FILE
    
    # Bereken volgende sector (size / 512, naar boven afgerond)
    size=$(stat -c%s "bin/$app_name.bin")
    num_sectors=$(( (size + 511) / 512 ))
    CURRENT_SECTOR=$(( CURRENT_SECTOR + num_sectors ))
done

# 3. Genereer de Trie (create.c moet nu app_offsets.txt inlezen)
gcc tls/create.c -o tls/create
./tls/create

# 4. Image samenstellen
# Zorg dat de header exact 1024 bytes (2 sectoren) is
truncate -s 1024 bin/app_header

# Plak header achter de bootloader (sector 1 & 2)
dd if=bin/app_header of=bin/bash.img bs=512 seek=1 conv=notrunc

# Plak alle apps erachteraan vanaf sector 3
CUR_APP_SECTOR=3
for app_src in ./src/apps/*; do
    app_name=$(basename "$app_src")
    dd if="bin/$app_name.bin" of=bin/bash.img bs=512 seek=$CUR_APP_SECTOR conv=notrunc
    
    size=$(stat -c%s "bin/$app_name.bin")
    num_sectors=$(( (size + 511) / 512 ))
    CUR_APP_SECTOR=$(( CUR_APP_SECTOR + num_sectors ))
done
