App.init({ roles: App.STAFF }).then((user) => {
  let upName = "", upType = "";   // the file picked in the form (added as an attachment after saving)
  const TYPES = ["homework", "practical", "project", "coding", "lab", "report", "video", "image"].map((t) => ({ value: t, label: t[0].toUpperCase() + t.slice(1) }));
  const page = new CrudPage("#app", {
    table: "assignments", title: "Assignments", icon: "journal-text", singular: "assignment", createLabel: "Create assignment",
    subtitle: "Create, link to batches, publish, then review submissions",
    columns: [
      { key: "title", label: "Assignment", render: (r) => `<div class="fw-semibold">${UI.esc(r.title)}</div><div class="small text-secondary text-capitalize">${UI.esc(r.assignment_type || "")}${r.organization ? " · " + UI.esc(r.organization.name) : ""}</div>` },
      { key: "deadline", label: "Deadline", render: (r) => (r.deadline ? `${UI.fmtDateTime(r.deadline)}${new Date(r.deadline) < new Date() ? ' <span class="badge text-bg-light">passed</span>' : ""}` : "—") },
      { key: "max_marks", label: "Max marks", render: (r) => UI.num(r.max_marks) },
      { key: "status", label: "Status", render: (r) => UI.badge(r.status) },
    ],
    filters: [{ name: "status", label: "Status", options: [{ value: "draft", label: "Draft" }, { value: "published", label: "Published" }, { value: "closed", label: "Closed" }] }],
    defaults: () => ({ organization_id: user.organization_id || "", assignment_type: "homework", max_marks: 10, allow_resubmit: true, max_resubmits: 2, allowed_types: "pdf,docx,jpg,jpeg,png,zip,txt" }),
    deleteWarning: "All student submissions for this assignment will be deleted too.",
    fields: [
      { name: "title", label: "Title", required: true, col: "col-md-8" },
      { name: "assignment_type", label: "Type", type: "select", options: TYPES, col: "col-md-4" },
      { name: "organization_id", label: "Organization", type: "select", required: true, options: () => App.options("organizations"), col: "col-md-4" },
      { name: "deadline", label: "Deadline", type: "datetime", col: "col-md-4" },
      { name: "max_marks", label: "Max marks", type: "number", min: 0, col: "col-md-4" },
      { name: "allow_resubmit", label: "Allow resubmission", type: "checkbox", col: "col-md-4" },
      { name: "max_resubmits", label: "Max resubmissions", type: "number", min: 0, step: 1, col: "col-md-4", visible: (v) => v.allow_resubmit },
      { name: "allowed_types", label: "Allowed file types", col: "col-md-4", help: "Comma separated, e.g. pdf,docx,jpg" },
      { name: "description", label: "Instructions", type: "textarea", rows: 5 },
      { type: "section", name: "_s_files", label: "Question paper / worksheet & who gets it", icon: "paperclip" },
      { name: "attach_file", label: "Upload file (question paper, worksheet, reference…)", type: "upload", purpose: "assignment", store: "path", col: "col-12",
        hint: "PDF, Word, PowerPoint, Excel, images or ZIP · max 10 MB · students can download it", buttonText: "Upload file",
        onUpload: (r) => { upName = r.name || ""; upType = r.type || ""; } },
      { name: "batch_ids", label: "Assign to batches", type: "multiselect", size: 4, col: "col-md-8", watch: ["organization_id"],
        options: async (v) => (await App.lookup("batches", v.organization_id ? { organization_id: v.organization_id } : {})).map((b) => ({ value: b.id, label: b.name })) },
      { name: "publish_now", label: "Publish now (students are notified)", type: "checkbox", col: "col-md-4" },
    ],
    toSave: (v) => { const d = { ...v }; delete d.attach_file; delete d.batch_ids; delete d.publish_now; return d; },
    afterSave: async (row, isNew, v) => {
      try {
        if (v.attach_file) { await API.call("assignment.addAttachment", { assignment_id: row.id, file_path: v.attach_file, file_name: upName || v.attach_file.split("/").pop().replace(/^[a-f0-9]{24}_/, ""), file_type: upType || null }); upName = ""; }
        if (v.batch_ids && v.batch_ids.length) await API.call("assignment.setBatches", { assignment_id: row.id, batch_ids: v.batch_ids });
        if (v.publish_now) await API.call("assignment.setStatus", { assignment_id: row.id, status: "published" });
      } catch (e) { UI.handle(e); }
      if (v.publish_now) { UI.toast("Assignment saved and published."); page.reload(); }
      else if (isNew) manage(row, true);
    },
    rowActions: [
      { icon: "gear", text: "Manage", label: "Batches, files & publish", class: "btn-outline-primary", onClick: (r) => manage(r) },
      { icon: "inbox", text: "Submissions", label: "Review submissions", class: "btn-outline-success", onClick: (r) => submissions(r) },
    ],
  });

  async function manage(row, isNew = false) {
    const m = UI.modal({ title: `Manage – ${row.title}`, size: "lg", body: `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>` });
    const load = async () => {
      let d;
      try { d = await API.call("assignment.get", { id: row.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      const a = d.assignment;
      const batches = await App.lookup("batches", { organization_id: a.organization_id }).catch(() => []);
      const linked = new Set(d.batches.map((b) => b?.id));
      m.body.innerHTML = `${isNew ? '<div class="alert alert-success small">Assignment created. Choose batches, add files if needed, then publish.</div>' : ""}
        <div class="d-flex align-items-center gap-2 mb-3"><strong>Status:</strong> ${UI.badge(a.status)}
          <div class="ms-auto d-flex gap-2">${a.status !== "published" ? `<button class="btn btn-success btn-sm" data-st="published"><i class="bi bi-send me-1"></i>Publish</button>` : `<button class="btn btn-outline-danger btn-sm" data-st="closed"><i class="bi bi-lock me-1"></i>Close</button>`}
          ${a.status !== "draft" ? `<button class="btn btn-outline-secondary btn-sm" data-st="draft">Move to draft</button>` : ""}</div></div>
        <h6>Batches</h6>
        <div class="border rounded p-2 mb-2" style="max-height:200px;overflow:auto">${batches.length ? batches.map((b) => `<div class="form-check"><input class="form-check-input" type="checkbox" value="${b.id}" id="ab${b.id}" ${linked.has(b.id) ? "checked" : ""}><label class="form-check-label" for="ab${b.id}">${UI.esc(b.name)}</label></div>`).join("") : '<div class="small text-secondary">No batches in this organization yet.</div>'}</div>
        <button class="btn btn-sm btn-primary mb-4" data-savebatches>Save batches</button>
        <h6>Attachments for students</h6>
        <ul class="list-group mb-2">${d.attachments.length ? d.attachments.map((f) => `<li class="list-group-item d-flex align-items-center gap-2"><i class="bi bi-paperclip"></i><a href="#" data-dl="${UI.esc(f.file_path)}">${UI.esc(f.file_name || "file")}</a><button class="btn btn-sm btn-light text-danger ms-auto" data-rmf="${f.id}"><i class="bi bi-x-lg"></i></button></li>`).join("") : '<li class="list-group-item small text-secondary">No attachments.</li>'}</ul>
        <div class="input-group"><input type="file" class="form-control" data-file><button class="btn btn-outline-primary" data-up>Upload</button></div>
        <div class="form-text">Max 10 MB. Allowed: pdf, docx, doc, pptx, xlsx, jpg, png, zip, txt.</div>`;
      m.body.querySelectorAll("[data-st]").forEach((b) => (b.onclick = async () => {
        if (b.dataset.st === "closed" && !(await UI.confirm("Students will no longer be able to submit.", { title: "Close assignment?", confirmText: "Close", danger: true }))) return;
        if (await UI.run(() => API.call("assignment.setStatus", { assignment_id: a.id, status: b.dataset.st }))) { load(); page.reload(); }
      }));
      m.body.querySelector("[data-savebatches]").onclick = async () => {
        const ids = [...m.body.querySelectorAll(".form-check-input:checked")].map((c) => c.value);
        if (await UI.run(() => API.call("assignment.setBatches", { assignment_id: a.id, batch_ids: ids }))) load();
      };
      m.body.querySelector("[data-up]").onclick = async () => {
        const f = m.body.querySelector("[data-file]").files[0];
        if (!f) return UI.warn("Please choose a file first.");
        const up = await UI.run(() => API.upload(f, "assignment"), { loading: "Uploading…", quiet: true });
        if (!up) return;
        if (await UI.run(() => API.call("assignment.addAttachment", { assignment_id: a.id, file_path: up.path, file_name: up.name, file_type: up.type }))) load();
      };
      m.body.querySelectorAll("[data-rmf]").forEach((b) => (b.onclick = async () => { if (await UI.confirm("Remove this attachment?", { confirmText: "Remove", danger: true })) { if (await UI.run(() => API.call("assignment.removeAttachment", { id: b.dataset.rmf }))) load(); } }));
      bindDownloads(m.body);
    };
    load();
  }

  function bindDownloads(root) {
    root.querySelectorAll("[data-dl]").forEach((a) => (a.onclick = async (e) => { e.preventDefault(); const r = await UI.run(() => API.fileUrl(a.dataset.dl), { loading: "Opening file…", success: false }); if (r) window.open(r, "_blank", "noopener"); }));
  }

  async function submissions(row) {
    const m = UI.modal({ title: `Submissions – ${row.title}`, size: "xl", body: `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>` });
    const load = async () => {
      let d;
      try { d = await API.call("assignment.submissions", { assignment_id: row.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      const a = d.assignment;
      m.body.innerHTML = d.rows.length ? `<div class="table-responsive"><table class="table align-middle"><thead><tr><th>Student</th><th>Submitted</th><th>Answer</th><th>Status</th><th>Marks</th><th></th></tr></thead><tbody>
        ${d.rows.map((s) => `<tr><td><div class="fw-semibold">${UI.esc(s.user?.full_name)}</div><div class="small text-secondary">${UI.esc(s.user?.roll_number || s.user?.email || "")} · attempt ${s.attempt_number}</div></td>
          <td class="small">${UI.fmtDateTime(s.submitted_at)}</td>
          <td class="small" style="max-width:320px">${s.content ? `<div class="clamp-2">${UI.esc(s.content)}</div>` : ""}${s.link_url ? `<div><a href="${UI.esc(s.link_url)}" target="_blank" rel="noopener noreferrer"><i class="bi bi-link-45deg"></i> Link</a></div>` : ""}
            ${(s.files || []).map((f) => `<div><a href="#" data-dl="${UI.esc(f.file_path)}"><i class="bi bi-paperclip"></i> ${UI.esc(f.file_name || "file")}</a></div>`).join("")}</td>
          <td>${UI.badge(s.status)}</td><td>${s.marks_obtained !== null ? `${UI.num(s.marks_obtained)} / ${UI.num(a.max_marks)}` : "—"}</td>
          <td><button class="btn btn-sm btn-primary" data-eval="${s.id}">Review</button></td></tr>`).join("")}</tbody></table></div>` : UI.empty("No submissions yet.", "inbox");
      bindDownloads(m.body);
      m.body.querySelectorAll("[data-eval]").forEach((b) => (b.onclick = async () => {
        const s = d.rows.find((x) => x.id === b.dataset.eval);
        await UI.formModal({
          title: `Review – ${s.user?.full_name}`, size: "",
          fields: [
            { name: "status", label: "Decision", type: "select", required: true, col: "col-12", options: [{ value: "evaluated", label: "Evaluated (final marks)" }, { value: "needs_correction", label: "Needs correction (student can resubmit)" }, { value: "returned", label: "Returned" }, { value: "under_review", label: "Under review" }] },
            { name: "marks_obtained", label: `Marks (out of ${UI.num(a.max_marks)})`, type: "number", min: 0, max: a.max_marks ?? undefined, step: 0.25, col: "col-12", validate: (v, all) => (all.status === "evaluated" && (v === null || v === "") ? "Please enter the marks." : "") },
            { name: "feedback", label: "Feedback for the student", type: "textarea", rows: 4, col: "col-12" },
          ],
          values: { status: s.status === "evaluated" ? "evaluated" : "evaluated", marks_obtained: s.marks_obtained, feedback: s.feedback },
          onSubmit: async (v) => { const r = await API.call("assignment.evaluate", { id: s.id, ...v }); UI.toast(r.message); load(); },
        });
      }));
    };
    load();
  }
});
