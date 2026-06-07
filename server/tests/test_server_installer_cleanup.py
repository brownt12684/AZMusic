import importlib.util
import sqlite3
from pathlib import Path


def test_server_installer_cleanup_clears_workflow_but_preserves_settings(
    tmp_path,
) -> None:
    installer = _load_server_installer_module()
    install_dir = tmp_path / "AZMusic" / "Server"
    server_dir = install_dir / "server"
    storage_dir = server_dir / "storage"
    pieces_dir = storage_dir / "pieces" / "piece-1"
    piece_state_dir = storage_dir / "piece_state"
    pieces_dir.mkdir(parents=True)
    piece_state_dir.mkdir(parents=True)
    (pieces_dir / "candidate.musicxml").write_text("<score-partwise />", encoding="utf-8")
    (piece_state_dir / "piece-1.json").write_text("{}", encoding="utf-8")
    (storage_dir / "pairing_state.json").write_text('{"server_id":"test"}', encoding="utf-8")
    (storage_dir / "processing_settings.json").write_text("{}", encoding="utf-8")

    database_path = server_dir / "azmusic_server.db"
    _create_runtime_database(database_path)

    backup_dir = installer.clear_workflow_data(install_dir)

    assert backup_dir is not None
    assert (backup_dir / "azmusic_server.db").exists()
    assert (backup_dir / "pieces" / "piece-1" / "candidate.musicxml").exists()
    assert (backup_dir / "piece_state" / "piece-1.json").exists()
    assert not any((storage_dir / "pieces").iterdir())
    assert not any((storage_dir / "piece_state").iterdir())
    assert (storage_dir / "pairing_state.json").exists()
    assert (storage_dir / "processing_settings.json").exists()

    with sqlite3.connect(database_path) as connection:
        for table in (
            "annotation_layers",
            "piece_history_drafts",
            "media_assets",
            "review_items",
            "background_jobs",
            "score_versions",
            "pieces",
        ):
            count = connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            assert count == 0
        profile_count = connection.execute("SELECT COUNT(*) FROM profiles").fetchone()[0]
        assert profile_count == 1


def _load_server_installer_module():
    script_path = (
        Path(__file__).resolve().parents[2]
        / "scripts"
        / "server-installer"
        / "azmusic_server_installer.py"
    )
    spec = importlib.util.spec_from_file_location("azmusic_server_installer", script_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _create_runtime_database(database_path: Path) -> None:
    database_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(database_path) as connection:
        for table in (
            "profiles",
            "pieces",
            "score_versions",
            "review_items",
            "background_jobs",
            "media_assets",
            "piece_history_drafts",
            "annotation_layers",
        ):
            connection.execute(f'CREATE TABLE "{table}" (id TEXT PRIMARY KEY)')
            connection.execute(f'INSERT INTO "{table}" (id) VALUES (?)', (f"{table}-1",))
        connection.commit()
