# Every command is exactly 6 bytes long, leaving room for 2 extra bytes to store the LBA sector
# This script is also responsible for building the apps

from pathlib import Path
import subprocess

root = Path(__file__).parent.parent
apps_dir = root / "src/apps"
apps_bin_dir = root / "bin/apps"
apps_error_dir = root / "src/apps_error"
app_header = apps_bin_dir / "app_header"
apps = []

# Make sure the error directory exists
apps_error_dir.mkdir(exist_ok=True)

def nasm_bin(filename, outname):
    try:
        subprocess.run(["nasm", filename, "-o", outname, "-f", "bin"], check=True)
        return 0
    except subprocess.CalledProcessError:
        return 1

for app in apps_dir.iterdir():
    if len(app.stem) > 6:
        app.rename(apps_error_dir / Path(app.name))
        letters = []
        for letter in app.stem:
            letters.append(letter)

print(apps)
