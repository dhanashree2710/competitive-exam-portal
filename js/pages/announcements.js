App.init().then(async (user) => {
  const el = document.getElementById("app");
  const feed = async (box) => {
    box.innerHTML = `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>`;
    try {
      const r = await API.call("announcements.feed");
      box.innerHTML = r.rows.length ? r.rows.map((a) => `<div class="card mb-3 ${a.priority === "high" || a.priority === "urgent" ? "border-start border-4 border-danger" : ""}"><div class="card-body">
        <div class="d-flex gap-2 align-items-start"><h5 class="mb-1 flex-grow-1">${UI.esc(a.title)}</h5>${a.priority && a.priority !== "normal" ? UI.badge(a.priority) : ""}</div>
        <div class="small text-secondary mb-2">${UI.fmtDateTime(a.published_at)}${a.author ? " · " + UI.esc(a.author.full_name) : ""}</div>
        <div style="white-space:pre-wrap">${UI.esc(a.body)}</div>
        ${a.attachment_url ? (/\.(png|jpe?g|gif|webp|svg)(\?|$)/i.test(a.attachment_url)
          ? `<img src="${UI.esc(a.attachment_url)}" alt="" class="img-fluid rounded mt-3" style="max-height:340px">`
          : `<a class="btn btn-outline-primary btn-sm mt-3" href="${UI.esc(a.attachment_url)}" target="_blank" rel="noopener"><i class="bi bi-paperclip me-1"></i>${UI.esc(a.attachment_name || "Attachment")}</a>`) : ""}
        </div></div>`).join("") : `<div class="card">${UI.empty("No announcements right now.", "megaphone")}</div>`;
    } catch (e) { box.innerHTML = UI.empty(e.message, "exclamation-circle"); }
  };
  if (!App.isStaff()) {
    el.innerHTML = `<h1 class="page-title mb-3"><i class="bi bi-megaphone me-2 text-primary"></i>Announcements</h1><div id="feed"></div>`;
    return feed(document.getElementById("feed"));
  }
  el.innerHTML = `<ul class="nav nav-tabs mb-3"><li class="nav-item"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#manage">Manage</button></li>
    <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#feedTab" id="feedBtn">What I see</button></li></ul>
    <div class="tab-content"><div class="tab-pane fade show active" id="manage"></div><div class="tab-pane fade" id="feedTab"></div></div>`;
  document.getElementById("feedBtn").addEventListener("shown.bs.tab", () => feed(document.getElementById("feedTab")));
  const TARGETS = [{ value: "all", label: "Everyone" }, { value: "organization", label: "An organization" }, { value: "batch", label: "A batch" }, { value: "role", label: "A role" }];
  new CrudPage("#manage", {
    table: "announcements", title: "Announcements", icon: "megaphone", singular: "announcement", createLabel: "New announcement",
    columns: [
      { key: "title", label: "Title", render: (r) => `<div class="fw-semibold">${UI.esc(r.title)}</div><div class="small text-secondary clamp-2">${UI.esc(r.body)}</div>` },
      { key: "target_type", label: "Audience", render: (r) => UI.esc(r.target_type === "batch" ? `Batch: ${r.batch?.name || "—"}` : r.target_type === "role" ? `Role: ${UI.roleLabel(r.target_role)}` : r.target_type === "organization" ? "Organization" : "Everyone") },
      { key: "priority", label: "Priority", render: (r) => UI.badge(r.priority) },
      { key: "published_at", label: "Published", render: (r) => UI.fmtDateTime(r.published_at) },
      { key: "expires_at", label: "Expires", render: (r) => (r.expires_at ? UI.fmtDateTime(r.expires_at) : "Never") },
    ],
    defaults: () => ({ target_type: user.role === "super_admin" ? "all" : "organization", priority: "normal", organization_id: user.organization_id || "" }),
    fields: [
      { name: "title", label: "Title", required: true, col: "col-12" },
      { name: "body", label: "Message", type: "textarea", rows: 5, required: true },
      { name: "organization_id", label: "Posted by organization", type: "select", required: true, options: () => App.options("organizations"), col: "col-md-6" },
      { name: "priority", label: "Priority", type: "select", options: ["low", "normal", "high", "urgent"].map((p) => ({ value: p, label: p[0].toUpperCase() + p.slice(1) })), col: "col-md-6" },
      { name: "target_type", label: "Who should see it", type: "select", required: true, options: TARGETS, col: "col-md-6", help: "“Everyone” means all users of the portal." },
      { name: "target_org", label: "Organization", type: "select", col: "col-md-6", options: () => App.options("organizations"), visible: (v) => v.target_type === "organization", help: "Defaults to the posting organization." },
      { name: "target_batch", label: "Batch", type: "select", col: "col-md-6", required: true, options: () => App.options("batches"), visible: (v) => v.target_type === "batch" },
      { name: "target_role", label: "Role", type: "select", col: "col-md-6", required: true, options: ["student", "faculty", "institute_admin", "college_admin"].map((r) => ({ value: r, label: UI.roleLabel(r) })), visible: (v) => v.target_type === "role" },
      { name: "published_at", label: "Publish at", type: "datetime", col: "col-md-6", help: "Leave empty to publish now." },
      { name: "expires_at", label: "Expires at", type: "datetime", col: "col-md-6" },
      { name: "attachment_url", label: "Attachment (image, PDF, Word, PowerPoint…)", type: "upload", purpose: "announcement", nameField: "attachment_name", col: "col-12", buttonText: "Attach file" },
      { name: "attachment_name", label: "", type: "hidden", col: "d-none" },
    ],
    toSave: (v) => { const d = { ...v }; if (d.target_type !== "batch") d.target_batch = null; if (d.target_type !== "role") d.target_role = null; if (d.target_type !== "organization") d.target_org = null; if (!d.published_at) delete d.published_at; return d; },
  });
});
