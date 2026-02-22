from pathlib import Path
import subprocess
src = Path(__file__).parent / "src"
bin_dir = Path(__file__).parent / "bin"
apps = src / "apps"
terminal = src / "bash/bash.asm"
app_header = bin_dir / "app_header"

def nasm(filename):
    outfile = bin_dir / Path(filename).stem
    try:
        subprocess.run(["nasm", str(filename), "-o", str(outfile)], check=True)
    except subprocess.CalledProcessError as e:
        return 1

nasm(terminal)

with open(app_header, "wb") as f:
    for app in apps.iterdir():
        print(app)