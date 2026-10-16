"""Cloud Notes - une petite application web de notes.

- Interface web rendue par le serveur (Flask + template HTML)
- Données stockées dans PostgreSQL (table "notes")
- La connexion à la base vient de la variable d'environnement DATABASE_URL
"""
import os
import time

import psycopg
from flask import Flask, jsonify, redirect, render_template, request, url_for

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://notes:notes@localhost:5432/notes"
)


def get_conn():
    """Ouvre une connexion à PostgreSQL."""
    return psycopg.connect(DATABASE_URL)


def init_db(retries: int = 10, delay: float = 2.0):
    """Crée la table si elle n'existe pas (réessaie si la base démarre encore)."""
    for attempt in range(1, retries + 1):
        try:
            with get_conn() as conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS notes (
                        id SERIAL PRIMARY KEY,
                        content TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                    """
                )
            return
        except psycopg.OperationalError:
            if attempt == retries:
                raise
            time.sleep(delay)


def create_app():
    app = Flask(__name__)
    init_db()

    @app.get("/")
    def index():
        with get_conn() as conn:
            rows = conn.execute(
                "SELECT id, content, created_at FROM notes ORDER BY created_at DESC"
            ).fetchall()
        return render_template("index.html", notes=rows)

    @app.post("/notes")
    def add_note():
        content = (request.form.get("content") or "").strip()
        if content:
            with get_conn() as conn:
                conn.execute("INSERT INTO notes (content) VALUES (%s)", (content,))
        return redirect(url_for("index"))

    @app.post("/notes/<int:note_id>/delete")
    def delete_note(note_id: int):
        with get_conn() as conn:
            conn.execute("DELETE FROM notes WHERE id = %s", (note_id,))
        return redirect(url_for("index"))

    @app.get("/health")
    def health():
        """Health check : vérifie que l'app ET la base répondent."""
        try:
            with get_conn() as conn:
                conn.execute("SELECT 1")
            return jsonify(status="ok", database="ok"), 200
        except Exception as exc:  # noqa: BLE001
            return jsonify(status="error", database=str(exc)), 503

    return app
