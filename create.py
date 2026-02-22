from pathlib import Path
import subprocess
import shutil

src = Path(__file__).resolve().parent / "src"
bin_dir = Path(__file__).resolve().parent / "bin"
apps = src / "apps"
terminal = src / "bash/bash.asm"
app_header = bin_dir / "app_header"
app_error = src / "app_error"
app_error.mkdir(parents=True, exist_ok=True)

def nasm(filename):
    outfile = bin_dir / Path(filename).stem
    try:
        subprocess.run(["/usr/bin/nasm", "-f", "bin", str(filename), "-o", str(outfile)], check=True)
        return 1
    except subprocess.CalledProcessError:
        return 0

nasm(terminal)
app_trie = {}
apps_list = []
with open(app_header, "wb") as f:
    for app in apps.iterdir():
        if len(app.stem) > 6:
            print(f"{app.stem} has a too long name ({len(app.stem)})")
            shutil.move(str(app), str(app_error / app.name))
        else:
            apps_list.append(app)
    apps_list.sort()
    prefix = ""
    for app in apps_list:
        app = str(app.stem) + "-" * (6 - (len(str(app.stem))))
        letters = ["-"] * len(app)
        i = 0
        for letter in app:
            letters[i] = letter
            i += 1
    





