App.init().then(async (user) => {
  const el = document.getElementById("app");
  const TYPES = [["challenge", "Challenge", "trophy"], ["quiz", "Quiz", "patch-question"], ["revision", "Revision", "arrow-repeat"], ["practice", "Practice", "pencil"], ["timed_test", "Timed test", "stopwatch"]];
  const typeOpt = TYPES.map(([v, l]) => ({ value: v, label: l }));
  const icon = (t) => (TYPES.find((x) => x[0] === t) || [0, 0, "lightning-charge"])[2];

  if (user.role !== "student") {
    new CrudPage("#app", {
      table: "activities", title: "Activities", icon: "lightning-charge", singular: "activity", createLabel: "New activity",
      subtitle: "Timed challenges, quizzes and revision tasks that keep students engaged",
      columns: [
        { key: "title", label: "Activity", render: (r) => `<div class="d-flex gap-2 align-items-center"><span class="avatar g9"><i class="bi bi-${icon(r.activity_type)}"></i></span><div><div class="fw-semibold">${UI.esc(r.title)}</div><div class="small text-secondary text-capitalize">${UI.esc(String(r.activity_type || "").replace("_", " "))}${r.exam ? " · " + UI.esc(r.exam.title) : ""}</div></div></div>` },
        { key: "points", label: "Points", render: (r) => `<span class="badge text-bg-light"><i class="bi bi-star-fill text-warning"></i> ${r.points ?? 0}</span>` },
        { key: "start_time", label: "Window", render: (r) => `<div class="small">${UI.fmtDateTime(r.start_time)}</div><div class="small text-secondary">${r.end_time ? "to " + UI.fmtDateTime(r.end_time) : ""}</div>` },
        { key: "completions", label: "Completed by", render: (r) => `${r.completions || 0} student(s)` },
        { key: "is_active", label: "Status", render: (r) => UI.activeBadge(r.is_active) },
      ],
      filters: [{ name: "activity_type", label: "Type", options: typeOpt }],
      defaults: () => ({ organization_id: user.organization_id || "", activity_type: "quiz", points: 10, is_active: true }),
      toForm: (r) => ({ ...r, resource_link: /^https?:/.test(r.resource_url || "") ? r.resource_url : "", resource_file: /^https?:/.test(r.resource_url || "") ? "" : (r.resource_url || "") }),
      toSave: (v) => { const d = { ...v, resource_url: v.resource_file || v.resource_link || null }; delete d.resource_file; delete d.resource_link; return d; },
      fields: [
        { name: "title", label: "Title", required: true, col: "col-md-8" },
        { name: "activity_type", label: "Type", type: "select", options: typeOpt, col: "col-md-4" },
        { name: "organization_id", label: "Organization", type: "select", required: true, options: () => App.options("organizations"), col: "col-md-4" },
        { name: "points", label: "Points", type: "number", min: 0, step: 1, col: "col-md-4" },
        { name: "duration_minutes", label: "Duration (min)", type: "number", min: 1, step: 1, col: "col-md-4" },
        { name: "start_time", label: "Starts", type: "datetime", col: "col-md-4" },
        { name: "end_time", label: "Ends", type: "datetime", col: "col-md-4" },
        { name: "is_active", label: "Active", type: "checkbox", col: "col-md-4" },
        { name: "exam_id", label: "Linked exam (optional)", type: "select", options: () => App.options("exams", {}, (e) => `${e.title} (${e.status})`), col: "col-md-6" },
        { name: "resource_link", label: "Resource link (optional)", type: "url", placeholder: "https://…", col: "col-md-6" },
        { name: "resource_file", label: "…or upload a resource file", type: "upload", purpose: "assignment_file", store: "path", col: "col-12",
          hint: "PDF, Word, PowerPoint, images, audio or video · max 10 MB" },
        { name: "description", label: "Instructions", type: "textarea", rows: 3 },
      ],
      rowActions: [{ icon: "inbox", text: "Responses", label: "See who completed it and their uploaded answers", class: "btn-outline-primary", onClick: (r) => responses(r) }],
    });
    async function responses(a) {
      const m = UI.modal({ title: `Responses – ${a.title}`, size: "lg", body: `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>` });
      let r; try { r = await API.call("activity.responses", { activity_id: a.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      const withFile = r.rows.filter((x) => x.file_path).length;
      m.body.innerHTML = `<div class="d-flex flex-wrap gap-2 mb-3"><span class="chip chip-completed">${r.rows.length} completed</span><span class="chip chip-scheduled"><i class="bi bi-paperclip"></i> ${withFile} with an answer file</span></div>
        ${r.rows.length ? `<div class="table-responsive"><table class="table table-sm align-middle"><thead><tr><th>Student</th><th>Batch</th><th>Completed</th><th>Answer</th></tr></thead><tbody>
        ${r.rows.map((x) => `<tr><td><div class="fw-semibold">${UI.esc(x.full_name)}</div><div class="small text-secondary">${UI.esc(x.roll_number || x.email)}</div></td><td class="small">${UI.esc(x.batch || "—")}</td>
          <td class="small">${UI.fmtDateTime(x.completed_at)}</td><td>${x.file_path ? `<button class="btn btn-sm btn-outline-primary" data-file="${UI.esc(x.file_path)}"><i class="bi bi-file-earmark-arrow-down me-1"></i>${UI.esc(x.file_name || "Download")}</button>` : '<span class="small text-secondary">No file</span>'}
          ${x.note ? `<div class="small text-secondary mt-1"><i class="bi bi-chat-left-text me-1"></i>${UI.esc(x.note)}</div>` : ""}</td></tr>`).join("")}</tbody></table></div>` : UI.empty("Nobody has completed this activity yet.", "inbox")}`;
      m.body.querySelectorAll("[data-file]").forEach((b) => (b.onclick = () => UI.openFile(b.dataset.file)));
    }
    return;
  }

  el.innerHTML = `<div class="page-head"><h1 class="page-title"><i class="bi bi-lightning-charge me-2 text-primary"></i>Activities</h1>
    <div class="ms-auto card px-3 py-2 d-flex flex-row align-items-center gap-2"><i class="bi bi-star-fill text-warning fs-5"></i><div><div class="fw-bold fs-5 lh-1" id="pts">0</div><div class="small text-secondary">points earned</div></div></div></div>
    <div id="list"><div class="text-center py-5"><div class="loader-ring mx-auto"></div></div></div>`;
  const load = async () => {
    let r;
    try { r = await API.call("student.activities"); } catch (e) { document.getElementById("list").innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    document.getElementById("pts").textContent = r.points;
    document.getElementById("list").innerHTML = r.rows.length ? `<div class="row g-3 stagger">${r.rows.map((a) => `
      <div class="col-md-6 col-xl-4"><div class="card card-hover h-100"><div class="card-body d-flex flex-column">
        <div class="d-flex gap-3 align-items-start mb-2"><span class="avatar g9" style="width:44px;height:44px"><i class="bi bi-${icon(a.activity_type)}"></i></span>
          <div class="flex-grow-1"><h5 class="mb-0">${UI.esc(a.title)}</h5><div class="small text-secondary text-capitalize">${UI.esc(String(a.activity_type || "").replace("_", " "))} · <i class="bi bi-star-fill text-warning"></i> ${a.points} pts</div></div>
          ${a.completed ? '<span class="badge text-bg-success"><i class="bi bi-check2"></i> Done</span>' : UI.badge(a.state)}</div>
        ${a.description ? `<p class="small text-secondary mb-2" style="white-space:pre-wrap">${UI.esc(a.description)}</p>` : ""}
        <ul class="list-unstyled small text-secondary mb-3">${a.duration_minutes ? `<li><i class="bi bi-clock me-1"></i>${a.duration_minutes} minutes</li>` : ""}${a.end_time ? `<li><i class="bi bi-calendar-x me-1"></i>Ends ${UI.fmtDateTime(a.end_time)}</li>` : ""}</ul>
        <div class="mt-auto d-flex flex-wrap gap-2">
          ${a.resource_url ? `<button class="btn btn-outline-primary btn-sm" data-res="${UI.esc(a.resource_url)}" data-start="${a.id}"><i class="bi bi-${/^https?:/.test(a.resource_url) ? "box-arrow-up-right" : "file-earmark-arrow-down"} me-1"></i>Open resource</button>` : ""}
          ${a.exam ? `<a class="btn btn-outline-primary btn-sm" href="my-exams.html" data-start="${a.id}"><i class="bi bi-pencil-square me-1"></i>${UI.esc(a.exam.title)}</a>` : ""}
          ${!a.completed && a.state === "open" ? `<button class="btn btn-primary btn-sm" data-done="${a.id}"><i class="bi bi-cloud-arrow-up me-1"></i>Submit / upload</button>` : ""}
        </div></div></div></div>`).join("")}</div>` : `<div class="card">${UI.empty("No activities yet. Check back soon!", "lightning-charge")}</div>`;
    document.querySelectorAll("[data-start]").forEach((b) => b.addEventListener("click", () => API.call("student.activityEvent", { activity_id: b.dataset.start, event: "start" }).catch(() => {})));
    document.querySelectorAll("[data-res]").forEach((b) => b.addEventListener("click", () => UI.openFile(b.dataset.res)));
    document.querySelectorAll("[data-done]").forEach((b) => (b.onclick = async () => {
      const act = r.rows.find((x) => x.id === b.dataset.done);
      let fileName = "";
      const res = await UI.formModal({
        title: `Complete – ${act?.title || "activity"}`, submitText: "Submit & complete", size: "lg",
        fields: [
          { name: "_info", type: "section", label: "Upload your answer sheet or work (optional) – points are added as soon as you submit", icon: "cloud-arrow-up" },
          { name: "file_path", label: "Answer file", type: "upload", purpose: "activity_answer", store: "path", col: "col-12", extra: { activity_id: act.id },
            hint: "PDF, Word, PowerPoint, Excel, images or ZIP · max 10 MB", buttonText: "Upload answer file", onUpload: (_, __) => {} },
          { name: "note", label: "Note for your teacher (optional)", type: "textarea", rows: 2, col: "col-12" },
        ],
        values: {},
        onSubmit: (v) => API.call("student.activityEvent", { activity_id: act.id, event: "complete", file_path: v.file_path || null, file_name: fileName || (v.file_path || "").split("/").pop().replace(/^[a-f0-9]{24}_/, "") || null, note: v.note || null }),
        onOpen: () => {},
      });
      if (res) { UI.success(res.message, "🎉 Great job!"); load(); }
    }));
  };
  load();
});
