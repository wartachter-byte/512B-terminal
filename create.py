from pathlib import Path
import subprocess
import shutil

char_set = "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
src = Path(__file__).resolve().parent / "src"
bin_dir = Path(__file__).resolve().parent / "bin"
apps_dir = src / "apps"
terminal = src / "bash/bash.asm"
app_header = bin_dir / "app_header"
app_error = src / "app_error"
app_error.mkdir(parents=True, exist_ok=True)

def nasm(filename):
    outfile = bin_dir / Path(filename).stem
    try:
        subprocess.run(
        ["/usr/bin/nasm", "-f", "bin", str(filename),"-o", str(outfile) + ".img", "-l", str(outfile) + ".lst"],
         check=True
         )
        return 1
    except subprocess.CalledProcessError:
        return 0

def Full_to_SegOff(pointer) -> int:
    segment = (pointer & 0xFFF00) >> 4
    offset = pointer & 0x000FF
    ret_val = (segment << 16) + offset
    ret_val = struct.pack("<I", ret_val)
    return ret_val

nasm(terminal)
app_trie = {}
apps = []

for app in apps_dir.iterdir():
    if len(app.stem) > 6:
        print(f"{app.stem} has a too long name ({len(app.stem)})")
        shutil.move(str(app), str(app_error / app.name))
    else:
        node = app_trie
        for key in app.stem:
            if key not in node:
                node[key] = {}
                node = node[key]
        node["*"] = "\0"

app_header_data = [""]

print(app_trie.items())

#with open(app_header, "wb") as f:
    #f.write(app_header_data)
