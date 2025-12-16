from flask import Flask, request, jsonify
import os
import socket
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production")
HOSTNAME = socket.gethostname()

# ---- HARD REQUIREMENT ----
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required")

# ---- DB INIT (fail fast) ----
try:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=5,
    )

    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS messages (
                id SERIAL PRIMARY KEY,
                content TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """))
except Exception as e:
    raise RuntimeError(f"Database initialization failed: {e}")

@app.route("/")
def index():
    return jsonify({
        "message": "Hello from Flask on Kubernetes",
        "environment": ENVIRONMENT,
        "hostname": HOSTNAME
    })

@app.route("/message", methods=["POST"])
def add_message():
    data = request.get_json(force=True)
    content = data.get("content")
    if not content:
        return jsonify({"error": "content is required"}), 400

    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO messages (content) VALUES (:content)"),
            {"content": content}
        )

    return jsonify({"status": "saved"}), 201

@app.route("/messages")
def list_messages():
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT id, content, created_at FROM messages ORDER BY created_at DESC")
        ).fetchall()

    return jsonify([
        {"id": r.id, "content": r.content, "created_at": r.created_at.isoformat()}
        for r in rows
    ])

@app.route("/health")
def health():
    return jsonify(status="healthy"), 200

@app.route("/ready")
def ready():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return jsonify(status="ready"), 200
    except SQLAlchemyError as e:
        return jsonify(status="not ready", error=str(e)), 500
