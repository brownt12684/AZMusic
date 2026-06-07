from fastapi.testclient import TestClient
from server.main import app


def test_health_returns_service_metadata() -> None:
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "server": "azmusic",
        "version": "0.2.0",
    }
