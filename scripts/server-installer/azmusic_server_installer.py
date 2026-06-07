"""Clickable Windows installer for the AZMusic server package."""

from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path

PRESERVED_RELATIVE_PATHS = {
    Path("server") / ".env",
    Path("server") / "azmusic_server.db",
    Path("server") / "azmusic_server.db-shm",
    Path("server") / "azmusic_server.db-wal",
}
PRESERVED_RELATIVE_DIRS = {
    Path("server") / "storage",
}
WORKFLOW_TABLES = (
    "annotation_layers",
    "piece_history_drafts",
    "media_assets",
    "review_items",
    "background_jobs",
    "score_versions",
    "position_books",
    "pieces",
)
GENERATED_STORAGE_DIRS = (
    Path("server") / "storage" / "pieces",
    Path("server") / "storage" / "piece_state",
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
        packages = sorted(root.glob("AZMusic-server-windows-*.zip"))
        if packages:
            return packages[-1]

    raise FileNotFoundError("Could not find embedded AZMusic server package ZIP.")


def default_install_dir() -> Path:
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        return Path(local_app_data) / "AZMusic" / "Server"
    return Path.home() / "AppData" / "Local" / "AZMusic" / "Server"


def stop_running_server_processes() -> None:
    if os.name != "nt":
        return

    subprocess.run(
        ["taskkill", "/F", "/IM", "azmusic-server.exe"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def is_preserved(relative_path: Path) -> bool:
    if relative_path in PRESERVED_RELATIVE_PATHS:
        return True
    return any(
        relative_path == preserved_dir or preserved_dir in relative_path.parents
        for preserved_dir in PRESERVED_RELATIVE_DIRS
    )


def copy_runtime(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.rglob("*"):
        relative_path = item.relative_to(source)
        target = destination / relative_path

        if is_preserved(relative_path) and target.exists():
            continue

        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue

        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)


def extract_package(package_zip: Path, install_dir: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="azmusic-server-install-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        with zipfile.ZipFile(package_zip) as archive:
            archive.extractall(temp_dir)

        package_roots = [
            path for path in temp_dir.iterdir()
            if path.is_dir() and path.name.startswith("AZMusic-server-windows-")
        ]
        if not package_roots:
            raise RuntimeError("The embedded package did not contain an AZMusic server folder.")

        copy_runtime(package_roots[0], install_dir)


def clear_workflow_data(install_dir: Path) -> Path | None:
    server_dir = install_dir / "server"
    database_path = server_dir / "azmusic_server.db"
    storage_dir = server_dir / "storage"
    has_workflow_data = database_path.exists() or any(
        (install_dir / relative_dir).exists()
        for relative_dir in GENERATED_STORAGE_DIRS
    )
    if not has_workflow_data:
        return None

    backup_dir = (
        install_dir
        / "cleanup-backups"
        / f"installer-workflow-clear-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )
    backup_dir.mkdir(parents=True, exist_ok=True)
    _backup_runtime_file(database_path, backup_dir)
    _backup_runtime_file(Path(f"{database_path}-wal"), backup_dir)
    _backup_runtime_file(Path(f"{database_path}-shm"), backup_dir)
    for relative_dir in GENERATED_STORAGE_DIRS:
        _backup_runtime_dir(install_dir / relative_dir, backup_dir / relative_dir.name)

    if database_path.exists():
        _clear_workflow_tables(database_path)

    if storage_dir.exists():
        for relative_dir in GENERATED_STORAGE_DIRS:
            target = install_dir / relative_dir
            if target.exists():
                _clear_directory_contents(target, storage_dir)
            else:
                target.mkdir(parents=True, exist_ok=True)

    return backup_dir


def _backup_runtime_file(source: Path, backup_dir: Path) -> None:
    if source.exists():
        shutil.copy2(source, backup_dir / source.name)


def _backup_runtime_dir(source: Path, destination: Path) -> None:
    if source.exists():
        shutil.copytree(source, destination, dirs_exist_ok=True)


def _clear_workflow_tables(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        cursor = connection.cursor()
        cursor.execute("PRAGMA foreign_keys=OFF")
        tables = {
            row[0]
            for row in cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        for table in WORKFLOW_TABLES:
            if table in tables:
                cursor.execute(f'DELETE FROM "{table}"')
        connection.commit()
        cursor.execute("VACUUM")


def _clear_directory_contents(directory: Path, storage_root: Path) -> None:
    resolved_directory = directory.resolve()
    resolved_storage_root = storage_root.resolve()
    try:
        resolved_directory.relative_to(resolved_storage_root)
    except ValueError as exc:
        raise RuntimeError(
            f"Refusing to clear unexpected storage path: {resolved_directory}"
        ) from exc

    for child in directory.iterdir():
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()


def run_powershell(script_path: Path, *arguments: str) -> int:
    command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script_path),
        *arguments,
    ]
    return subprocess.call(command)


def powershell_literal(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def create_shortcut(
    name: str,
    target: Path | str,
    arguments: str,
    working_dir: Path,
    shortcut_dir: Path,
) -> None:
    shortcut_dir.mkdir(parents=True, exist_ok=True)
    shortcut_path = shortcut_dir / f"{name}.lnk"
    script = f"""
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut({powershell_literal(shortcut_path)})
$shortcut.TargetPath = {powershell_literal(target)}
$shortcut.Arguments = {powershell_literal(arguments)}
$shortcut.WorkingDirectory = {powershell_literal(working_dir)}
$shortcut.Save()
"""
    subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        check=True,
    )


def create_shortcuts(install_dir: Path) -> None:
    desktop = Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Desktop"
    start_menu = (
        Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
        / "Microsoft"
        / "Windows"
        / "Start Menu"
        / "Programs"
        / "AZMusic"
    )
    powershell = (
        Path(os.environ.get("SystemRoot", "C:\\Windows"))
        / "System32"
        / "WindowsPowerShell"
        / "v1.0"
        / "powershell.exe"
    )
    shortcuts = {
        "Setup AZMusic Server": _powershell_file_argument(
            install_dir / "setup-azmusic-server.ps1"
        ),
        "Start AZMusic Server": _powershell_file_argument(
            install_dir / "start-azmusic-server.ps1"
        ),
        "Open AZMusic Server Setup Page": _powershell_file_argument(
            install_dir / "open-server-setup-page.ps1"
        ),
        "Install AZMusic Processing Tools": _powershell_file_argument(
            install_dir / "install-processing-tool-helpers.ps1"
        ),
    }

    for shortcut_name, arguments in shortcuts.items():
        create_shortcut(shortcut_name, powershell, arguments, install_dir, desktop)
        create_shortcut(shortcut_name, powershell, arguments, install_dir, start_menu)


def _powershell_file_argument(script_path: Path) -> str:
    return f'-NoProfile -ExecutionPolicy Bypass -File "{script_path}"'


def launch_server(install_dir: Path) -> None:
    subprocess.Popen(
        [
            "cmd",
            "/c",
            "start",
            "AZMusic Server",
            str(install_dir / "Start AZMusic Server.cmd"),
        ],
        cwd=install_dir,
        shell=False,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Install AZMusic Server for Windows.")
    parser.add_argument("--install-dir", type=Path, default=default_install_dir())
    parser.add_argument("--skip-setup", action="store_true")
    parser.add_argument("--skip-shortcuts", action="store_true")
    parser.add_argument("--setup-skip-processing-tool-prompt", action="store_true")
    parser.add_argument("--start-server", action="store_true")
    parser.add_argument("--preserve-workflow-data", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    install_dir = args.install_dir.expanduser().resolve()

    print("AZMusic Server Installer")
    print("")
    print("This installer includes the AZMusic server runtime.")
    print("Audiveris, MuseScore Studio, and Tesseract OCR remain separately installed tools.")
    print("Setup will provide guided links or winget options for those tools.")
    print("")
    print(f"Install folder: {install_dir}")
    print("")

    package_zip = find_embedded_package()
    print(f"Using package: {package_zip.name}")
    stop_running_server_processes()
    extract_package(package_zip, install_dir)
    print("Server files installed.")

    if args.preserve_workflow_data:
        print("Preserved existing import workflow data and generated assets.")
    else:
        backup_dir = clear_workflow_data(install_dir)
        if backup_dir is None:
            print("No existing import workflow data found to clear.")
        else:
            print("Cleared existing import workflow data and generated assets.")
            print(f"Workflow backup: {backup_dir}")

    if not args.skip_shortcuts:
        create_shortcuts(install_dir)
        print("Desktop and Start Menu shortcuts created.")

    if not args.skip_setup:
        setup_arguments: list[str] = []
        if args.setup_skip_processing_tool_prompt:
            setup_arguments.append("-SkipProcessingToolPrompt")
        setup_exit_code = run_powershell(install_dir / "setup-azmusic-server.ps1", *setup_arguments)
        if setup_exit_code != 0:
            print(f"Setup failed with exit code {setup_exit_code}.")
            return setup_exit_code

    should_start = args.start_server
    if not args.quiet and not should_start:
        answer = input("Start AZMusic Server now? [Y/n] ").strip().lower()
        should_start = answer in ("", "y", "yes")

    if should_start:
        launch_server(install_dir)
        print("AZMusic Server start window opened.")

    print("")
    print("Installation complete.")
    print("Use the desktop shortcuts to start the server, open setup, or install processing tools.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
