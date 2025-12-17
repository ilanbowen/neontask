from flask import Flask, request, jsonify, render_template
import os
import socket
from sqlalchemy import create_engine, text

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production")
HOSTNAME = socket.gethostname()

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required")

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

PAGE = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Hello World + DB</title>
  <style>
    body { font-family: system-ui, Arial; margin: 24px; max-width: 900px; }
    .card { border: 1px solid #ddd; border-radius: 10px; padding: 16px; margin: 12px 0; }
    input, button { padding: 10px; font-size: 16px; }
    input { width: 70%; }
    button { cursor: pointer; }
    ul { padding-left: 18px; }
    .muted { color: #666; font-size: 14px; }
    .row { display: flex; gap: 10px; flex-wrap: wrap; }
  </style>
</head>
<body>
  <h1>Hello World + Database</h1>
  <p class="muted">
    Environment: <b>{{env}}</b> · Pod: <b>{{host}}</b>
  </p>

  <div class="card">
    <h2>Save a message</h2>
    <div class="row">
      <input id="msg" placeholder="Type something..." />
      <button onclick="save()">Save</button>
      <button onclick="load()">Refresh</button>
    </div>
    <p id="status" class="muted"></p>
  </div>

  <div class="card">
    <h2>Messages</h2>
    <ul id="list"></ul>
  </div>

<script>
async function load() {
  const r = await fetch("/messages");
  const data = await r.json();
  const list = document.getElementById("list");
  list.innerHTML = "";
  for (const m of data) {
    const li = document.createElement("li");
    li.textContent = `${m.id}: ${m.content} (${m.created_at})`;
    list.appendChild(li);
  }
}

async function save() {
  const v = document.getElementById("msg").value.trim();
  if (!v) return;
  document.getElementById("status").textContent = "Saving...";
  const r = await fetch("/message", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({content: v})
  });
  const data = await r.json();
  document.getElementById("status").textContent = r.ok ? "Saved ✅" : ("Error: " + JSON.stringify(data));
  document.getElementById("msg").value = "";
  await load();
}

load();
</script>
</body>
</html>
"""

@app.route("/")
def index():
    return render_template("index.html", environment=ENVIRONMENT, hostname=HOSTNAME)

@app.route("/message", methods=["POST"])
def add_message():
    data = request.get_json(force=True)
    content = data.get("content")
    if not content:
        return jsonify({"error": "content is required"}), 400

    with engine.begin() as conn:
        conn.execute(text("INSERT INTO messages (content) VALUES (:content)"), {"content": content})

    return jsonify({"status": "saved"}), 201

@app.route("/messages")
def list_messages():
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, content, created_at FROM messages ORDER BY created_at DESC")).fetchall()
    return jsonify([{"id": r.id, "content": r.content, "created_at": r.created_at.isoformat()} for r in rows])

@app.route("/health")
def health():
    return jsonify(status="healthy"), 200

@app.route("/ready")
def ready():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return jsonify(status="ready"), 200
