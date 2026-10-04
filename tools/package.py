"""Package the runtime addon, requiring every CI platform binary."""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/webframe"
REQUIRED = [
    "webframe.windows.x86_64.dll", "webframe.windows.x86_32.dll",
    "webframe.windows.arm64.dll", "webframe.macos.universal.dylib",
    "webframe.linux.x86_64.so", "webframe.linux.arm64.so",
    "android/webframe-release.aar", "webframe.ios.arm64.dylib",
]
missing = [name for name in REQUIRED if not (ADDON / "bin" / name).is_file()]
if missing:
    raise SystemExit("Missing binaries: " + ", ".join(missing))
output = ROOT / "dist/WebFrame-all-platforms.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(ADDON.rglob("*")):
        relative = path.relative_to(ADDON)
        if not path.is_file() or relative.parts[0] == "native" or relative.parts[:2] == ("mobile", "android"):
            continue
        if path.suffix in {".import", ".lib", ".exp", ".pdb"}:
            continue
        if relative.parts[0] == "bin" and relative.parts[1] != "licenses" and relative.relative_to("bin").as_posix() not in REQUIRED:
            continue
        archive.write(path, path.relative_to(ROOT))
    for name in ("README.md", "LICENSE", "THIRD_PARTY.md"):
        archive.write(ROOT / name, "addons/webframe/" + name)
print(output)
