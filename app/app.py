from flask import Flask, jsonify, request, render_template_string, redirect, url_for
import os, socket
from datetime import datetime

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

app = Flask(__name__)

APP_VERSION = "1.1.0"

# DB connection string: postgresql+psycopg2://user:pass@host:5432/dbname
DATABASE_URL = os.environ.get("DATABASE_URL")

def get_engine():
    if not DATABASE_URL:
        return None
    return create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=5, max_overflow=5)

def init_db():
    eng = get_engine()
    if not eng:
        return
    with eng.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS messages (
              id SERIAL PRIMARY KEY,
              name TEXT NOT NULL,
              message TEXT NOT NULL,
              created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        """))

@app.before_first_request
def _startup():
    init_db()

PAGE = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Hello World on EKS</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
  <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container">
      <span class="navbar-brand">Hello World on Kubernetes</span>
      <span class="navbar-text text-secondary small">
        v{{ app_version }} • {{ hostname }} • {{ environment }}
      </span>
    </div>
  </nav>

  <main class="container py-4">
    <div class="row g-4">
      <div class="col-lg-6">
        <div class="card shadow-sm">
          <div class="card-body">
            <h5 class="card-title">Leave a message</h5>
            <p class="card-text text-muted">Stored in RDS (PostgreSQL) and shown below.</p>

            {% if db_missing %}
              <div class="alert alert-warning">
                DATABASE_URL is not set. UI works, but nothing will be stored.
              </div>
            {% endif %}

            <form method="post" action="{{ url_for('create_message') }}">
              <div class="mb-3">
                <label class="form-label">Your name</label>
                <input class="form-control" name="name" required maxlength="100" />
              </div>
              <div class="mb-3">
                <label class="form-label">Message</label>
                <textarea class="form-control" name="message" required maxlength="1000" rows="3"></textarea>
              </div>
              <button class="btn btn-primary">Save</button>
              <a class="btn btn-outline-secondary" href="{{ url_for('index') }}">Refresh</a>
            </form>
          </div>
        </div>

        <div class="mt-3 small text-muted">
          <div><b>Health:</b> <a href="/health">/health</a> • <a href="/ready">/ready</a> • <a href="/info">/info</a></div>
          <div><b>API:</b> <a href="/api/messages">/api/messages</a></div>
        </div>
      </div>

      <div class="col-lg-6">
        <div class="card shadow-sm">
          <div class="card-body">
            <h5 class="card-title">Recent messages</h5>
            <div class="table-responsive">
              <table class="table table-sm align-middle">
                <thead>
                  <tr>
                    <th>When</th><th>Name</th><th>Message</th>
                  </tr>
                </thead>
                <tbody>
                  {% for m in messages %}
                    <tr>
                      <td class="text-nowrap">{{ m["created_at"] }}</td>
                      <td class="text-nowrap">{{ m["name"] }}</td>
                      <td style="white-space: pre-wrap;">{{ m["message"] }}</td>
                    </tr>
                  {% endfor %}
                  {% if messages|length == 0 %}
                    <tr><td colspan="3" class="text-muted">No messages yet.</td></tr>
                  {% endif %}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {% if error %}
          <div class="alert alert-danger mt-3">{{ error }}</div>
        {% endif %}
      </div>
    </div>
  </main>
</body>
</html>
"""

@app.route("/", methods=["GET"])
def index():
    hostname = socket.gethostname()
    environment = os.environ.get("ENVIRONMENT", "development")

    messages = []
    error = None
    db_missing = not bool(DATABASE_URL)

    try:
        eng = get_engine()
        if eng:
            with eng.connect() as conn:
                rows = conn.execute(text("""
                    SELECT name, message, created_at
                    FROM messages
                    ORDER BY created_at DESC
                    LIMIT 25
                """)).mappings().all()
                messages = [
                    {
                        "name": r["name"],
                        "message": r["message"],
                        "created_at": r["created_at"].strftime("%Y-%m-%d %H:%M:%S %Z") if r["created_at"] else ""
                    }
                    for r in rows
                ]
    except SQLAlchemyError as e:
        error = f"DB error: {e.__class__.__name__}"

    return render_template_string(
        PAGE,
        app_version=APP_VERSION,
        hostname=hostname,
        environment=environment,
        messages=messages,
        db_missing=db_missing,
        error=error,
    )

@app.route("/message", methods=["POST"])
def create_message():
    name = request.form.get("name", "").strip()
    message = request.form.get("message", "").strip()

    if not name or not message:
        return redirect(url_for("index"))

    eng = get_engine()
    if eng:
        with eng.begin() as conn:
            conn.execute(
                text("INSERT INTO messages(name, message) VALUES (:name, :message)"),
                {"name": name[:100], "message": message[:1000]},
            )

    return redirect(url_for("index"))

@app.route("/api/messages", methods=["GET"])
def api_messages():
    eng = get_engine()
    if not eng:
        return jsonify({"error": "DATABASE_URL not set"}), 400

    with eng.connect() as conn:
        rows = conn.execute(text("""
            SELECT id, name, message, created_at
            FROM messages
            ORDER BY created_at DESC
            LIMIT 100
        """)).mappings().all()

    return jsonify({"items": [dict(r) for r in rows]})

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "hello-world-app"}), 200

@app.route("/ready")
def ready():
    # Optional DB check here if you want readiness to depend on DB connectivity
    return jsonify({"status": "ready", "service": "hello-world-app"}), 200

@app.route("/info")
def info():
    import sys
    return jsonify({
        "hostname": socket.gethostname(),
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "python_version": sys.version,
        "app_version": APP_VERSION
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
