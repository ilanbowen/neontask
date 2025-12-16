from flask import Flask, request, jsonify, render_template_string, redirect, url_for
import os
import socket
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# ------------------------------------------------------------------------------
# App setup
# ------------------------------------------------------------------------------
app = Flask(__name__)

HOSTNAME = socket.gethostname()
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
DATABASE_URL = os.environ.get("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required")

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=5,
)

# ------------------------------------------------------------------------------
# Database initialization (Flask 3 compatible)
# ------------------------------------------------------------------------------
def init_db():
    try:
        with engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS messages (
                    id SERIAL PRIMARY KEY,
                    content TEXT NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
    except SQLAlchemyError as e:
        # Fail fast so Kubernetes restarts if DB is unreachable
        raise RuntimeError(f"Database initialization failed: {e}")

# Initialize DB on startup
with app.app_context():
    init_db()

# ------------------------------------------------------------------------------
# UI Template (simple but nicer than JSON)
# ------------------------------------------------------------------------------
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Hello World on EKS</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f4f6f8;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 700px;
            margin: 40px auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
        }
        .meta {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 20px;
        }
        form {
            margin-bottom: 30px;
        }
        textarea {
            width: 100%;
            height: 80px;
            padding: 10px;
            font-size: 1em;
        }
        button {
            margin-top: 10px;
            padding: 10px 16px;
            font-size: 1em;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover {
            background: #2980b9;
        }
        .message {
            padding: 12px;
            border-bottom: 1px solid #ddd;
        }
        .timestamp {
            font-size: 0.8em;
            color: #999;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Hello from Flask on Kubernetes 🚀</h1>
    <div class="meta">
        Environment: <strong>{{ environment }}</strong><br>
        Hostname: <strong>{{ hostname }}</strong>
    </div>

    <form method="POST" action="/message">
        <textarea name="content" placeholder="Write a message..." required></textarea>
        <button type="submit">Save message</button>
    </form>

    <h2>Messages</h2>
    {% for msg in messages %}
        <div class="message">
            {{ msg.content }}
            <div class="timestamp">{{ msg.created_at }}</div>
        </div>
    {% else %}
        <p>No messages yet.</p>
    {% endfor %}
</div>
</body>
</html>
"""

# ------------------------------------------------------------------------------
# Routes
# ------------------------------------------------------------------------------
@app.route("/", methods=["GET"])
def index():
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT content, created_at FROM messages ORDER BY created_at DESC LIMIT 20")
        ).fetchall()

    messages = [
        {"content": row.content, "created_at": row.created_at}
        for row in rows
    ]

    return render_template_string(
        HTML_TEMPLATE,
        messages=messages,
        hostname=HOSTNAME,
        environment=ENVIRONMENT,
    )

@app.route("/message", methods=["POST"])
def add_message():
    content = request.form.get("content", "").strip()
    if content:
        with engine.begin() as conn:
            conn.execute(
                text("INSERT INTO messages (content) VALUES (:content)"),
                {"content": content},
            )
    return redirect(url_for("index"))

@app.route("/api/messages", methods=["GET"])
def api_messages():
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT id, content, created_at FROM messages ORDER BY created_at DESC LIMIT 50")
        ).fetchall()

    return jsonify([
        {"id": r.id, "content": r.content, "created_at": r.created_at.isoformat()}
        for r in rows
    ])

@app.route("/health")
def health():
    return jsonify(status="healthy", service="hello-world-app"), 200

@app.route("/ready")
def ready():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return jsonify(status="ready", service="hello-world-app"), 200
    except Exception:
        return jsonify(status="not ready"), 500

# ------------------------------------------------------------------------------
# Local dev fallback (Gunicorn ignores this)
# ------------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
