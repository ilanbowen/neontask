function fmtTime(iso) {
  try {
    const d = new Date(iso);
    return d.toLocaleString();
  } catch {
    return iso;
  }
}

function setStatus(msg) {
  document.getElementById("statusText").textContent = msg;
}

function setError(msg) {
  document.getElementById("errorText").textContent = msg || "";
}

function renderList(items) {
  const list = document.getElementById("list");
  list.innerHTML = "";

  if (!items || items.length === 0) {
    list.innerHTML = `<div class="item"><div class="item-content">No messages yet. Add the first one 👆</div></div>`;
    document.getElementById("countText").textContent = "0 messages";
    return;
  }

  document.getElementById("countText").textContent = `${items.length} message${items.length === 1 ? "" : "s"}`;

  for (const m of items) {
    const el = document.createElement("div");
    el.className = "item";
    el.innerHTML = `
      <div class="item-top">
        <div class="item-id">#${m.id}</div>
        <div class="item-time">${fmtTime(m.created_at)}</div>
      </div>
      <div class="item-content"></div>
    `;
    el.querySelector(".item-content").textContent = m.content;
    list.appendChild(el);
  }
}

async function refresh() {
  setError("");
  setStatus("Loading messages…");
  const res = await fetch("/messages");
  if (!res.ok) {
    setStatus("Failed.");
    setError("Failed to load messages.");
    return;
  }
  const data = await res.json();
  renderList(data);
  setStatus("Up to date.");
}

document.getElementById("msgForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  setError("");

  const input = document.getElementById("content");
  const content = input.value.trim();
  if (!content) return;

  setStatus("Saving…");
  const res = await fetch("/message", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content }),
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    setStatus("Failed.");
    setError(`Failed to save message. ${txt}`);
    return;
  }

  input.value = "";
  await refresh();
});

document.getElementById("refreshBtn").addEventListener("click", refresh);
refresh();
