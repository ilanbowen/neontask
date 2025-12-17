async function refresh() {
  const res = await fetch("/messages");
  const data = await res.json();
  document.getElementById("out").textContent = JSON.stringify(data, null, 2);
}

document.getElementById("msgForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const content = document.getElementById("content").value;

  const res = await fetch("/message", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content }),
  });

  if (!res.ok) {
    alert("Failed to save message");
    return;
  }

  document.getElementById("content").value = "";
  await refresh();
});

document.getElementById("refreshBtn").addEventListener("click", refresh);

refresh();
