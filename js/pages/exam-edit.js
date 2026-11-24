App.init({ roles: App.STAFF }).then(async (user) => {
  const id = UI.qs("id");
  const el = document.getElementById("app");
  if (!id) { el.innerHTML = UI.empty("No exam selected.", "exclamation-circle"); return; }
  let data;

  el.innerHTML = `<div class="mb-3"><a href="exams.html" class="small text-decoration-none"><i class="bi bi-arrow-left"></i> All exams</a></div>
    <div id="head"></div>
    <ul class="nav nav-tabs mb-3" role="tablist">
      <li class="nav-item"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#tabQ">Questions</button></li>
      <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#tabA">Assigned to</button></li>
      <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#tabR" id="resultsTabBtn">Results</button></li>
    </ul>
    <div class="tab-content"><div class="tab-pane fade show active" id="tabQ"></div><div class="tab-pane fade" id="tabA"></div><div class="tab-pane fade" id="tabR"></div></div>`;

  async function load() {
    try { data = await API.call("exam.get", { id }); } catch (e) { el.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    renderHead(); renderQuestions(); renderAssign();
  }

  function renderHead() {
    const e = data.exam;
    const locked = data.attempts > 0;
    const btn = (status, label, cls, icon) => `<button class="btn ${cls}" data-status="${status}"><i class="bi bi-${icon} me-1"></i>${label}</button>`;
    let actions = "";
    if (e.status === "draft") actions = btn("live", "Go live now", "btn-success", "broadcast") + btn("scheduled", "Schedule", "btn-outline-primary", "calendar-check");
    if (e.status === "scheduled") actions = btn("live", "Go live now", "btn-success", "broadcast") + btn("draft", "Back to draft", "btn-outline-secondary", "arrow-counterclockwise");
    if (e.status === "live") actions = btn("completed", "End exam", "btn-danger", "stop-circle");
    if (e.status === "completed") actions = btn("live", "Re-open", "btn-outline-success", "arrow-repeat") + btn("archived", "Archive", "btn-outline-secondary", "archive");
    if (e.status === "archived") actions = btn("draft", "Restore to draft", "btn-outline-secondary", "arrow-counterclockwise");
    document.getElementById("head").innerHTML = `<div class="card mb-3"><div class="card-body d-flex flex-wrap gap-3 align-items-start">
      <div class="flex-grow-1"><h1 class="page-title mb-1">${UI.esc(e.title)} ${UI.badge(e.status)}</h1>
      <div class="text-secondary small d-flex flex-wrap gap-3">
        <span><i class="bi bi-list-ol"></i> ${e.total_questions || 0} questions · ${UI.num(e.total_marks)} marks</span>
        <span><i class="bi bi-clock"></i> ${e.duration_minutes || "—"} min</span>
        <span><i class="bi bi-calendar"></i> ${UI.fmtDateTime(e.start_time)}${e.end_time ? " → " + UI.fmtDateTime(e.end_time) : ""}</span>
        <span><i class="bi bi-arrow-repeat"></i> ${e.attempt_limit || 1} attempt(s)</span>
        <span><i class="bi bi-people"></i> ${data.attempts} attempt(s) so far</span>
        ${e.negative_marking ? '<span class="text-danger"><i class="bi bi-dash-circle"></i> Negative marking</span>' : ""}
      </div>${locked ? '<div class="small text-warning mt-1"><i class="bi bi-lock"></i> Questions are locked because students have started this exam.</div>' : ""}</div>
      <div class="d-flex flex-wrap gap-2">${actions}<button class="btn btn-light" id="editExam"><i class="bi bi-pencil me-1"></i>Settings</button></div></div></div>`;
    document.querySelectorAll("[data-status]").forEach((b) => b.addEventListener("click", () => setStatus(b.dataset.status)));
    document.getElementById("editExam").addEventListener("click", editSettings);
  }

  async function setStatus(status) {
    const msgs = { live: "Assigned students will be able to start the exam immediately.", completed: "Students who haven't submitted won't be able to start any more. In-progress attempts can still be submitted until their timer ends.", draft: "Students will no longer see this exam.", scheduled: "The exam will open automatically at its start time.", archived: "The exam will be hidden from lists." };
    if (!(await UI.confirm(msgs[status], { title: "Change exam status?", confirmText: "Yes, continue", danger: status === "completed" }))) return;
    if (await UI.run(() => API.call("exam.setStatus", { exam_id: id, status }))) load();
  }

  async function editSettings() {
    await UI.formModal({
      title: "Exam settings", fields: window.EXAM_FIELDS(user), values: data.exam,
      onSubmit: async (v) => { const r = await API.call("crud.save", { table: "exams", id, data: v }); UI.toast(r.message); load(); },
    });
  }

  // ---------------- questions ----------------
  function renderQuestions() {
    const locked = data.attempts > 0;
    const t = document.getElementById("tabQ");
    t.innerHTML = `<div class="card"><div class="card-header d-flex flex-wrap gap-2 align-items-center">Questions in this exam
      ${locked ? "" : `<div class="ms-auto d-flex gap-2"><button class="btn btn-sm btn-outline-primary" id="autoPick"><i class="bi bi-shuffle me-1"></i>Auto-pick</button><button class="btn btn-sm btn-primary" id="addQ"><i class="bi bi-plus-lg me-1"></i>Add from bank</button></div>`}</div>
      <div class="table-responsive"><table class="table mb-0"><thead><tr><th>#</th><th class="w-50">Question</th><th>Type</th><th>Section</th><th>Marks</th><th></th></tr></thead><tbody>
      ${data.questions.length ? data.questions.map((q, i) => `<tr><td>${i + 1}</td>
        <td><div class="clamp-2">${UI.esc(UI.stripHtml(q.question?.question_text))}</div><div class="small text-secondary">${UI.esc(q.question?.subject?.name || "")} ${q.question?.difficulty ? UI.badge(q.question.difficulty) : ""} ${q.question?.status && !["approved", "published"].includes(q.question.status) ? UI.badge(q.question.status) : ""}</div></td>
        <td class="small">${UI.esc(String(q.question?.question_type || "").replace(/_/g, " "))}</td>
        <td><input class="form-control form-control-sm" style="width:110px" value="${UI.esc(q.section || "")}" data-section="${q.id}" placeholder="—" ${locked ? "disabled" : ""}></td>
        <td><input type="number" class="form-control form-control-sm" style="width:80px" min="0.25" step="0.25" value="${UI.esc(q.marks ?? q.question?.marks ?? 1)}" data-marks="${q.id}" ${locked ? "disabled" : ""}></td>
        <td class="text-end">${locked ? "" : `<button class="btn btn-sm btn-light text-danger" data-rmq="${q.id}" title="Remove"><i class="bi bi-x-lg"></i></button>`}</td></tr>`).join("")
        : `<tr><td colspan="6">${UI.empty("No questions yet. Add them from the question bank or use auto-pick.", "patch-question")}</td></tr>`}
      </tbody></table></div></div>`;
    if (locked) return;
    t.querySelector("#addQ").onclick = pickQuestions;
    t.querySelector("#autoPick").onclick = autoPick;
    t.querySelectorAll("[data-rmq]").forEach((b) => (b.onclick = async () => { if (await UI.confirm("Remove this question from the exam? It stays in the question bank.", { confirmText: "Remove" })) { if (await UI.run(() => API.call("exam.removeQuestion", { id: b.dataset.rmq }))) load(); } }));
    t.querySelectorAll("[data-marks]").forEach((inp) => inp.addEventListener("change", async () => {
      if (!(Number(inp.value) > 0)) { UI.warn("Marks must be greater than 0."); inp.value = 1; return; }
      if (await UI.run(() => API.call("exam.updateQuestion", { id: inp.dataset.marks, marks: Number(inp.value) }), { loading: false, success: "Marks updated." })) { const r = await API.call("exam.get", { id }); data = r; renderHead(); }
    }));
    t.querySelectorAll("[data-section]").forEach((inp) => inp.addEventListener("change", () => UI.run(() => API.call("exam.updateQuestion", { id: inp.dataset.section, section: inp.value }), { loading: false, success: "Section updated." })));
  }

  async function pickQuestions() {
    const have = new Set(data.questions.map((q) => q.question?.id));
    const m = UI.modal({ title: "Add questions from the bank", size: "xl", body: `
      <div class="row g-2 mb-2"><div class="col-md-4"><input class="form-control" placeholder="Search question text…" data-s></div>
      <div class="col-md-3"><select class="form-select" data-sub><option value="">All subjects</option></select></div>
      <div class="col-md-2"><select class="form-select" data-diff><option value="">Any level</option><option value="easy">Easy</option><option value="medium">Medium</option><option value="hard">Hard</option></select></div>
      <div class="col-md-3"><select class="form-select" data-st><option value="">Any status</option><option value="approved">Approved</option><option value="published">Published</option><option value="draft">Draft</option></select></div></div>
      <div data-list class="border rounded" style="max-height:55vh;overflow:auto"></div><div class="small text-secondary mt-2" data-info></div>`,
      footer: `<button class="btn btn-light" data-bs-dismiss="modal">Cancel</button><button class="btn btn-primary" data-add>Add selected (<span data-n>0</span>)</button>` });
    const picked = new Set();
    const sub = m.el.querySelector("[data-sub]");
    App.lookup("subjects").then((s) => (sub.innerHTML += s.map((x) => `<option value="${x.id}">${UI.esc(x.name)}</option>`).join(""))).catch(UI.handle.bind(UI));
    const list = async () => {
      const box = m.el.querySelector("[data-list]");
      box.innerHTML = `<div class="p-3 text-center"><span class="spinner-border spinner-border-sm"></span></div>`;
      try {
        const filters = { subject_id: sub.value, difficulty: m.el.querySelector("[data-diff]").value, status: m.el.querySelector("[data-st]").value };
        const r = await API.call("crud.list", { table: "questions", pageSize: 100, search: m.el.querySelector("[data-s]").value, filters });
        const rows = r.rows.filter((q) => !["rejected", "archived"].includes(q.status));
        box.innerHTML = rows.length ? rows.map((q) => `<label class="d-flex gap-2 p-2 border-bottom ${have.has(q.id) ? "opacity-50" : ""}">
          <input type="checkbox" class="form-check-input mt-1" value="${q.id}" ${have.has(q.id) ? "disabled checked" : picked.has(q.id) ? "checked" : ""}>
          <div class="flex-grow-1"><div class="clamp-2">${UI.esc(UI.stripHtml(q.question_text))}</div><div class="small text-secondary">${UI.esc(q.subject?.name || "—")} · ${UI.esc(q.question_type.replace(/_/g, " "))} · ${UI.num(q.marks)} marks ${UI.badge(q.status)} ${q.difficulty ? UI.badge(q.difficulty) : ""}${have.has(q.id) ? " · already added" : ""}</div></div></label>`).join("") : UI.empty("No questions match.", "search");
        m.el.querySelector("[data-info]").textContent = r.total > 100 ? `Showing the first 100 of ${r.total}. Use search or filters to narrow down.` : `${r.total} question(s) found.`;
        box.querySelectorAll("input:not([disabled])").forEach((c) => c.addEventListener("change", () => { c.checked ? picked.add(c.value) : picked.delete(c.value); m.el.querySelector("[data-n]").textContent = picked.size; }));
      } catch (e) { box.innerHTML = UI.empty(e.message, "exclamation-circle"); }
    };
    m.el.querySelector("[data-s]").addEventListener("input", UI.debounce(list));
    m.el.querySelectorAll("select").forEach((s) => s.addEventListener("change", list));
    m.el.querySelector("[data-add]").onclick = async () => {
      if (!picked.size) return UI.warn("Please tick at least one question.");
      if (await UI.run(() => API.call("exam.addQuestions", { exam_id: id, question_ids: [...picked] }))) { m.close(); load(); }
    };
    list();
  }

  async function autoPick() {
    await UI.formModal({
      title: "Auto-pick random questions", submitText: "Add questions",
      fields: [
        { name: "subject_id", label: "Subject", type: "select", options: () => App.options("subjects"), col: "col-md-6" },
        { name: "chapter_id", label: "Chapter", type: "select", watch: ["subject_id"], options: (v) => (v.subject_id ? App.options("chapters", { subject_id: v.subject_id }) : []), col: "col-md-6" },
        { name: "difficulty", label: "Difficulty", type: "select", options: [{ value: "easy", label: "Easy" }, { value: "medium", label: "Medium" }, { value: "hard", label: "Hard" }], col: "col-md-4" },
        { name: "count", label: "Number of questions", type: "number", min: 1, max: 200, step: 1, required: true, default: 10, col: "col-md-4" },
        { name: "section", label: "Section (optional)", col: "col-md-4" },
        { name: "include_drafts", label: "Include draft questions", type: "checkbox", col: "col-12" },
      ],
      onSubmit: async (v) => { const r = await API.call("exam.autoPick", { exam_id: id, ...v }); UI.success(r.message); load(); },
    });
  }

  // ---------------- assignments ----------------
  function renderAssign() {
    const t = document.getElementById("tabA");
    t.innerHTML = `<div class="card"><div class="card-header d-flex align-items-center">Batches and students who can take this exam
      <button class="btn btn-sm btn-primary ms-auto" id="assignBtn"><i class="bi bi-plus-lg me-1"></i>Assign</button></div>
      <ul class="list-group list-group-flush">${data.assignments.length ? data.assignments.map((a) => `<li class="list-group-item d-flex align-items-center gap-2">
        <i class="bi bi-${a.batch ? "people" : "person"} text-primary"></i><div class="flex-grow-1">${a.batch ? `Batch: <strong>${UI.esc(a.batch.name)}</strong>` : `Student: <strong>${UI.esc(a.user?.full_name)}</strong> <span class="text-secondary small">${UI.esc(a.user?.email)}</span>`}
        <div class="small text-secondary">Assigned ${UI.timeAgo(a.assigned_at)}</div></div>
        <button class="btn btn-sm btn-light text-danger" data-un="${a.id}"><i class="bi bi-x-lg"></i></button></li>`).join("") : `<li class="list-group-item">${UI.empty("Not assigned yet. Students only see exams that are assigned to them or their batch.", "people")}</li>`}</ul></div>`;
    t.querySelector("#assignBtn").onclick = assign;
    t.querySelectorAll("[data-un]").forEach((b) => (b.onclick = async () => { if (await UI.confirm("Students in this assignment will no longer see the exam (existing results are kept).", { title: "Remove assignment?", confirmText: "Remove", danger: true })) { if (await UI.run(() => API.call("exam.unassign", { id: b.dataset.un }))) load(); } }));
  }
  async function assign() {
    const org = data.exam.organization_id;
    await UI.formModal({
      title: "Assign exam", submitText: "Assign",
      fields: [
        { name: "batch_ids", label: "Batches", type: "multiselect", col: "col-12", options: () => App.options("batches", { organization_id: org }, (b) => `${b.name}${b.code ? " (" + b.code + ")" : ""}`) },
        { name: "user_ids", label: "Individual students (optional)", type: "multiselect", size: 8, col: "col-12", options: () => App.options("students", { organization_id: org }, (s) => `${s.full_name} · ${s.email}${s.roll_number ? " · " + s.roll_number : ""}`) },
      ],
      onSubmit: async (v) => { if (!v.batch_ids.length && !v.user_ids.length) throw new API.ApiError("Please select at least one batch or student."); const r = await API.call("exam.assign", { exam_id: id, ...v }); UI.toast(r.message); load(); },
    });
  }

  // ---------------- results ----------------
  document.getElementById("resultsTabBtn").addEventListener("shown.bs.tab", () => window.ExamResults.render(document.getElementById("tabR"), id));

  await load();
  if (UI.qs("new")) UI.info("Exam created! Now add questions, assign it to batches, then click ‘Go live’ or ‘Schedule’.", "Next steps");
});
