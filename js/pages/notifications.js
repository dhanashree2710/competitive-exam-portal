App.init().then(async () => {
  const el = document.getElementById("app");
  el.innerHTML = `<div class="d-flex flex-wrap gap-2 align-items-center mb-3"><h1 class="page-title"><i class="bi bi-bell me-2 text-primary"></i>Notifications</h1>
    <div class="ms-auto d-flex gap-2"><button class="btn btn-outline-primary" id="readAll"><i class="bi bi-check2-all me-1"></i>Mark all read</button>
    <button class="btn btn-outline-secondary" id="clear"><i class="bi bi-trash me-1"></i>Clear read</button></div></div><div class="card"><div class="list-group list-group-flush" id="list"></div></div>`;
  const icons = { exam: "pencil-square", result: "bar-chart-line", assignment: "journal-text", batch: "people" };
  const load = async () => {
    const list = document.getElementById("list");
    list.innerHTML = `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>`;
    let r;
    try { r = await API.call("notifications.list", { limit: 100 }); } catch (e) { list.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    App.setUnread(r.rows.filter((n) => !n.is_read).length);
    list.innerHTML = r.rows.length ? r.rows.map((n) => `<div class="list-group-item d-flex gap-3 align-items-start ${n.is_read ? "" : "bg-primary-subtle bg-opacity-25"}">
      <i class="bi bi-${icons[n.type] || "bell"} fs-5 text-primary"></i>
      <div class="flex-grow-1"><div class="fw-semibold">${UI.esc(n.title)}</div>${n.body ? `<div class="small">${UI.esc(n.body)}</div>` : ""}<div class="small text-secondary">${UI.timeAgo(n.created_at)}</div></div>
      <div class="d-flex gap-1">${n.action_url && /^[a-z-]+\.html(\?.*)?$/.test(n.action_url) ? `<a class="btn btn-sm btn-light" href="${UI.esc(n.action_url)}" data-open="${n.id}">Open</a>` : ""}
      ${n.is_read ? "" : `<button class="btn btn-sm btn-light" data-read="${n.id}" title="Mark as read"><i class="bi bi-check2"></i></button>`}</div></div>`).join("") : UI.empty("You have no notifications.", "bell");
    list.querySelectorAll("[data-read]").forEach((b) => (b.onclick = async () => { if (await UI.run(() => API.call("notifications.read", { id: b.dataset.read }), { loading: false, success: false })) load(); }));
    list.querySelectorAll("[data-open]").forEach((a) => a.addEventListener("click", () => API.call("notifications.read", { id: a.dataset.open }).catch(() => {})));
  };
  document.getElementById("readAll").onclick = async () => { if (await UI.run(() => API.call("notifications.read", {}))) load(); };
  document.getElementById("clear").onclick = async () => { if (await UI.confirm("Delete all notifications you've already read?", { confirmText: "Clear", danger: true })) { if (await UI.run(() => API.call("notifications.clear"))) load(); } };
  load();
});
