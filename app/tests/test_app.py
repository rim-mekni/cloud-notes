"""Tests automatiques lancés par le pipeline CI.

Ils utilisent une vraie base PostgreSQL (fournie par GitHub Actions).
"""
import uuid

import pytest

from app import create_app, get_conn


@pytest.fixture()
def client():
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_homepage_loads(client):
    resp = client.get("/")
    assert resp.status_code == 200


def test_add_note_is_saved_and_listed(client):
    text = f"test note {uuid.uuid4()}"
    resp = client.post("/notes", data={"content": text}, follow_redirects=True)
    assert resp.status_code == 200
    assert text in resp.get_data(as_text=True)

    # Une nouvelle requête (comme un rafraîchissement) voit toujours la note
    again = client.get("/")
    assert text in again.get_data(as_text=True)


def _count_notes():
    with get_conn() as conn:
        return conn.execute("SELECT count(*) FROM notes").fetchone()[0]


def test_empty_note_is_ignored(client):
    before = _count_notes()
    client.post("/notes", data={"content": "   "})
    assert _count_notes() == before
