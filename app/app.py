from flask import Flask, request, jsonify, Response
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
    html = f"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Hello World DB Demo</title>
  <style>
    body {{ font-family: system-ui, Arial, sans-serif; margin: 24px; max-width: 800px; }}
    .card {{ border: 1px solid #ddd; border-radius: 12px; padding: 16px; margin-bottom: 16px; }}
    input, button {{ font-size: 16px; padding: 10px; }}
    input {{ width: 100%; box-sizing: border-box; margin: 8px 0; }}
    button {{ cursor: pointer; }}
    .meta {{ color: #666; font-size: 14px; }}
    .row {{ display: flex; gap: 12px; }}
    .row > * {{ flex: 1; }}
    ul {{ padding-left: 18px; }}
    li {{ margin: 6px 0; }}
    .ok {{ color: #0a7; }}
    .err {{ color: #c00; white-space: pre-wrap; }}
  </style>
</head>
<body>
  <h1>Hello World + Postgres (EKS Demo)</h1>
  <p class="meta">
    Environment: <b>{ENVIRONMENT}</b> |
    Pod: <b>{HOSTNAME}</b>
  </p>

  <div class="card">
    <h2>1) Save a message</h2>
    <p>Type something and click <b>Save</b>. It will be stored in the database.</p>
    <input id="msg" placeholder="e.g. hello from the UI"/>
    <div class="row">
      <button onclick="saveMsg()">Save</button>
      <button onclick="loadMsgs()">Refresh list</button>
    </div>
    <p id="status"></p>
  </div>

  <div class="card">
    <h2>2) Messages in database</h2>
    <ul id="list"><li class="meta">Loading...</li></ul>
  </div>

<script>
async function loadMsgs() {{
  const list = document.getElementById("list");
  list.innerHTML = '<li class="meta">Loading...</li>';
  try {{
    const res = await fetch("/messages");
    const data = await res.json();
    if (!Array.isArray(data)) throw new Error("Unexpected response");
    if (data.length === 0) {{
      list.innerHTML = '<li class="meta">No messages yet. Add one above.</li>';
      return;
    }}
    list.innerHTML = "";
    for (const item of data) {{
      const li = document.createElement("li");
      const ts = item.created_at ? new Date(item.created_at).toLocaleString() : "";
      li.innerHTML = `<b>#${{item.id}}</b> ${{item.content}} <span class="meta">(${{ts}})</span>`;
      list.appendChild(li);
    }}
  }} catch (e) {{
    list.innerHTML = `<li class="err">Failed to load: ${{e}}</li>`;
  }}
}}

async function saveMsg() {{
  const input = document.getElementById("msg");
  const status = document.getElementById("status");
  const content = input.value.trim();
  if (!content) {{
    status.className = "err";
    status.textContent = "Please type a message first.";
    return;
  }}
  status.className = "meta";
  status.textContent = "Saving...";
  try {{
    const res = await fetch("/message", {{
      method: "POST",
      headers: {{ "Content-Type": "application/json" }},
      body: JSON.stringify({{ content }})
    }});
    const data = await res.json();
    if (!res.ok) {{
      throw new Error(JSON.stringify(data));
    }}
    input.value = "";
    status.className = "ok";
    status.textContent = "Saved!";
    await loadMsgs();
  }} catch (e) {{
    status.className = "err";
    status.textContent = "Save failed: " + e;
  }}
}}

loadMsgs();
</script>
</body>
</html>
"""
    return Response(html, mimetype="text/html")


@app.route("/message", methods=["POST"])
def add_message():
    data = request.get_json(force=True)
    content = data.get("content")
    if not content:
        return jsonify({"error": "content is required"}), 400

    with engine.begin() as conn:
        result = conn.execute(
            text("INSERT INTO messages (content) VALUES (:content) RETURNING id"),
            {"content": content}
            )
        new_id = result.scalar_one()
    return jsonify({"status": "saved", "id": new_id}), 201

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
