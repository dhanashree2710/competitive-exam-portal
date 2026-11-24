App.init({ roles: ["student"] }).then(async () => {
  const el = document.getElementById("app");
  el.innerHTML = `<h1 class="page-title mb-3"><i class="bi bi-journal-text me-2 text-primary"></i>My assignments</h1><div id="list"><div class="text-center py-5"><div class="loader-ring mx-auto"></div></div></div>`;
  let rows = [];
  const load = async () => {
    try { rows = (await API.call("student.assignments")).rows; } catch (e) { document.getElementById("list").innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    render();
  };
  const canSubmit = (a) => {
    if (a.status !== "published") return false;
    const s = a.my_submission;
    if (!s) return true;
    if (["needs_correction", "returned"].includes(s.status)) return true;
    return a.allow_resubmit && a.submission_count <= (a.max_resubmits ?? 0);
  };
  function render() {
    document.getElementById("list").innerHTML = rows.length ? `<div class="row g-3">${rows.map((a) => {
      const s = a.my_submission; const late = a.deadline && new Date(a.deadline) < new Date();
      return `<div class="col-md-6"><div class="card h-100"><div class="card-body d-flex flex-column">
        <div class="d-flex gap-2 align-items-start mb-1"><h5 class="mb-0 flex-grow-1">${UI.esc(a.title)}</h5>${s ? UI.badge(s.status) : a.status === "closed" ? UI.badge("closed") : late ? '<span class="badge text-bg-danger">Overdue</span>' : '<span class="badge text-bg-warning">Pending</span>'}</div>
        <div class="small text-secondary mb-2 text-capitalize">${UI.esc(a.assignment_type || "")} · ${a.max_marks != null ? UI.num(a.max_marks) + " marks · " : ""}Due ${UI.fmtDateTime(a.deadline)}</div>
        ${a.description ? `<div class="small mb-2" style="white-space:pre-wrap">${UI.esc(a.description)}</div>` : ""}
        ${(a.attachments || []).map((f) => `<div class="small"><a href="#" data-dl="${UI.esc(f.file_path)}"><i class="bi bi-paperclip"></i> ${UI.esc(f.file_name || "Attachment")}</a></div>`).join("")}
        ${s ? `<div class="border rounded p-2 small mt-2 bg-light"><div><strong>Your submission</strong> (attempt ${s.attempt_number}) · ${UI.fmtDateTime(s.submitted_at)}</div>
          ${s.marks_obtained !== null ? `<div class="mt-1">Marks: <strong>${UI.num(s.marks_obtained)} / ${UI.num(a.max_marks)}</strong></div>` : ""}
          ${s.feedback ? `<div class="mt-1"><i class="bi bi-chat-left-text"></i> ${UI.esc(s.feedback)}</div>` : ""}
          ${(s.files || []).map((f) => `<div><a href="#" data-dl="${UI.esc(f.file_path)}"><i class="bi bi-file-earmark"></i> ${UI.esc(f.file_name)}</a></div>`).join("")}</div>` : ""}
        <div class="mt-auto pt-3">${canSubmit(a) ? `<button class="btn btn-primary" data-submit="${a.id}"><i class="bi bi-upload me-1"></i>${s ? "Resubmit" : "Submit"}</button>` : ""}</div>
      </div></div></div>`; }).join("")}</div>` : `<div class="card">${UI.empty("No assignments yet.", "journal-text")}</div>`;
    document.querySelectorAll("[data-dl]").forEach((x) => (x.onclick = async (e) => { e.preventDefault(); const u = await UI.run(() => API.fileUrl(x.dataset.dl), { loading: "Opening file…", success: false }); if (u) window.open(u, "_blank", "noopener"); }));
    document.querySelectorAll("[data-submit]").forEach((b) => (b.onclick = () => submit(rows.find((a) => a.id === b.dataset.submit))));
  }
  async function submit(a) {
    const late = a.deadline && new Date(a.deadline) < new Date();
    const types = (a.allowed_types || "pdf,docx,jpg,jpeg,png,zip,txt").split(",").map((t) => "." + t.trim()).join(",");
    await UI.formModal({
      title: `Submit – ${a.title}`, submitText: "Submit",
      fields: [
        { name: "content", label: "Your answer / notes", type: "textarea", rows: 6, col: "col-12" },
        { name: "link_url", label: "Link (optional)", type: "url", placeholder: "https://github.com/…", col: "col-12", validate: (v) => (v && !/^https?:\/\/\S+$/i.test(v) ? "Links must start with http:// or https://" : "") },
        { name: "files", label: "Files (optional, up to 5, max 10 MB each)", type: "html", col: "col-12",
          render: (c) => { c.innerHTML = `<input type="file" class="form-control" multiple accept="${UI.esc(types)}"><div class="form-text">Allowed: ${UI.esc(a.allowed_types || "")}</div>`; },
          read: (form) => [...(form.querySelector('[data-field="files"] input[type=file]')?.files || [])],
          validate: (v) => (v.length > 5 ? "Please attach at most 5 files." : v.some((f) => f.size > 10 * 1024 * 1024) ? "Each file must be 10 MB or smaller." : "") },
      ],
      onSubmit: async (v) => {
        if (!v.content && !v.link_url && !v.files.length) throw new API.ApiError("Please write an answer, add a link, or attach a file.");
        if (late && !(await UI.confirm("The deadline has passed. Your submission will be marked as late.", { title: "Submit late?", confirmText: "Submit anyway" }))) throw new API.ApiError("Submission cancelled.", 0, true);
        const files = [];
        for (const [i, f] of v.files.entries()) {
          UI.loading(true, `Uploading file ${i + 1} of ${v.files.length}…`);
          try { files.push(await API.upload(f, "submission", { assignment_id: a.id })); } finally { UI.loading(false); }
        }
        const r = await API.call("student.submitAssignment", { assignment_id: a.id, content: v.content, link_url: v.link_url, files });
        UI.success(r.message); load();
      },
    });
  }
  load();
});
