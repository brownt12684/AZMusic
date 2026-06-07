"""Clickable Windows installer for the AZMusic client app."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

VC_RUNTIME_FILE_NAME = "vc_redist.x64.exe"
VC_RUNTIME_URL = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
VC_DOWNLOAD_TIMEOUT_SECONDS = 45
VC_INSTALL_TIMEOUT_SECONDS = 180
VC_RUNTIME_REQUIRED_DLLS = (
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
)


def resource_root() -> Path:
    return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))


def repo_root_from_source() -> Path:
    return Path(__file__).resolve().parents[2]


def find_embedded_package() -> Path:
    roots = [resource_root()]
    if not getattr(sys, "frozen", False):
        roots.append(repo_root_from_source() / "dist")

    for root in roots:
        packages = sorted(root.glob("AZMusic-windows-*.zip"))
        if packages:
            return packages[-1]

    raise FileNotFoundError("Could not find embedded AZMusic Windows client package ZIP.")


def default_install_dir() -> Path:
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        return Path(local_app_data) / "AZMusic" / "Client"
    return Path.home() / "AppData" / "Local" / "AZMusic" / "Client"


def stop_running_client_processes() -> None:
    if os.name != "nt":
        return

    subprocess.run(
        ["taskkill", "/F", "/IM", "azmusic.exe"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def system_vc_runtime_dll_paths() -> list[Path]:
    system_root = Path(os.environ.get("SystemRoot", "C:\\Windows"))
    return [
        system_root / "System32" / "MSVCP140.dll",
        system_root / "System32" / "VCRUNTIME140.dll",
        system_root / "System32" / "VCRUNTIME140_1.dll",
    ]


def has_system_vc_runtime() -> bool:
    return all(path.exists() for path in system_vc_runtime_dll_paths())


def has_bundled_vc_runtime(install_dir: Path) -> bool:
    return all((install_dir / dll_name).exists() for dll_name in VC_RUNTIME_REQUIRED_DLLS)


def has_vc_runtime(install_dir: Path) -> bool:
    return has_system_vc_runtime() or has_bundled_vc_runtime(install_dir)


def find_bundled_vc_runtime_installer() -> Path | None:
    roots = [resource_root()]
    if not getattr(sys, "frozen", False):
        roots.append(repo_root_from_source() / "dist" / "vendor")

    for root in roots:
        candidate = root / VC_RUNTIME_FILE_NAME
        if candidate.exists():
            return candidate
    return None


def download_vc_runtime_installer(installer_path: Path) -> None:
    print(f"Downloading Microsoft Visual C++ runtime from {VC_RUNTIME_URL}...")
    with urllib.request.urlopen(VC_RUNTIME_URL, timeout=VC_DOWNLOAD_TIMEOUT_SECONDS) as response:
        with installer_path.open("wb") as output:
            shutil.copyfileobj(response, output)


def install_vc_runtime() -> bool:
    print("Installing Microsoft Visual C++ x64 runtime required by the Windows client...")
    bundled_installer = find_bundled_vc_runtime_installer()
    if bundled_installer:
        installer_path = bundled_installer
        print(f"Using bundled Microsoft Visual C++ runtime installer: {installer_path.name}")
    else:
        installer_path = Path(tempfile.gettempdir()) / VC_RUNTIME_FILE_NAME
        try:
            download_vc_runtime_installer(installer_path)
        except Exception as exc:  # noqa: BLE001
            print(f"Unable to download Microsoft Visual C++ runtime: {exc}")
            print(f"Install it manually from {VC_RUNTIME_URL}, then run this installer again.")
            return False

    try:
        process = subprocess.run(
            [
                str(installer_path),
                "/install",
                "/quiet",
                "/norestart",
            ],
            check=False,
            timeout=VC_INSTALL_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print("Microsoft Visual C++ runtime installer timed out.")
        print(f"Install it manually from {VC_RUNTIME_URL}, then run this installer again.")
        return False

    if process.returncode in (0, 1638, 3010):
        return True

    print(f"Microsoft Visual C++ runtime installer exited with code {process.returncode}.")
    print(f"Install it manually from {VC_RUNTIME_URL}, then run this installer again.")
    return False


def ensure_vc_runtime(install_dir: Path) -> None:
    if has_vc_runtime(install_dir):
        print("Microsoft Visual C++ x64 runtime detected.")
        return

    if not install_vc_runtime():
        raise RuntimeError(
            "Microsoft Visual C++ x64 runtime is required before AZMusic can launch."
        )


def copy_runtime(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.rglob("*"):
        relative_path = item.relative_to(source)
        target = destination / relative_path
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)


def extract_package(package_zip: Path, install_dir: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="azmusic-client-install-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        with zipfile.ZipFile(package_zip) as archive:
            archive.extractall(temp_dir)

        package_roots = [
            path
            for path in temp_dir.iterdir()
            if path.is_dir() and path.name.startswith("AZMusic-windows-")
        ]
        if not package_roots:
            raise RuntimeError(
                "The embedded package did not contain an AZMusic Windows client folder."
            )

        copy_runtime(package_roots[0], install_dir)


def powershell_literal(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def create_shortcut(name: str, target: Path, working_dir: Path, shortcut_dir: Path) -> None:
    shortcut_dir.mkdir(parents=True, exist_ok=True)
    shortcut_path = shortcut_dir / f"{name}.lnk"
    script = f"""
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut({powershell_literal(shortcut_path)})
$shortcut.TargetPath = {powershell_literal(target)}
$shortcut.WorkingDirectory = {powershell_literal(working_dir)}
$shortcut.IconLocation = {powershell_literal(f"{target},0")}
$shortcut.Save()
"""
    subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        check=True,
    )


def create_shortcuts(install_dir: Path) -> None:
    app_exe = install_dir / "azmusic.exe"
    desktop = Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Desktop"
    start_menu = (
        Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
        / "Microsoft"
        / "Windows"
        / "Start Menu"
        / "Programs"
        / "AZMusic"
    )
    create_shortcut("AZMusic", app_exe, install_dir, desktop)
    create_shortcut("AZMusic", app_exe, install_dir, start_menu)


def launch_client(install_dir: Path) -> None:
    subprocess.Popen([str(install_dir / "azmusic.exe")], cwd=install_dir)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Install AZMusic for Windows.")
    parser.add_argument("--install-dir", type=Path, default=default_install_dir())
    parser.add_argument("--skip-shortcuts", action="store_true")
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args()


def main() -> int:
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass

    args = parse_args()
    install_dir = args.install_dir.expanduser().resolve()

    print("AZMusic Windows Client Installer")
    print("")
    print("This installs the AZMusic parent/student client app for this Windows user.")
    print(f"Install folder: {install_dir}")
    print("")

    package_zip = find_embedded_package()
    print(f"Using package: {package_zip.name}")
    stop_running_client_processes()
    extract_package(package_zip, install_dir)
    ensure_vc_runtime(install_dir)

    app_exe = install_dir / "azmusic.exe"
    if not app_exe.exists():
        raise FileNotFoundError(f"Installed client executable was not found: {app_exe}")

    print("Client files installed.")

    if not args.skip_shortcuts:
        create_shortcuts(install_dir)
        print("Desktop and Start Menu shortcuts created.")

    should_launch = args.launch
    if not args.quiet and not should_launch:
        answer = input("Launch AZMusic now? [Y/n] ").strip().lower()
        should_launch = answer in ("", "y", "yes")

    if should_launch:
        launch_client(install_dir)
        print("AZMusic launched.")

    print("")
    print("Installation complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
