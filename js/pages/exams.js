// shared exam form fields (also used on exam-edit page)
window.EXAM_FIELDS = (user) => [
  { name: "title", label: "Exam title", required: true, col: "col-md-8" },
  { name: "organization_id", label: "Organization", type: "select", required: true, options: () => App.options("organizations"), col: "col-md-4" },
  { name: "exam_category_id", label: "Exam category", type: "select", options: () => App.options("exam_categories"), col: "col-md-4" },
  { name: "duration_minutes", label: "Duration (minutes)", type: "number", min: 1, step: 1, required: true, col: "col-md-4" },
  { name: "attempt_limit", label: "Attempts allowed", type: "number", min: 1, step: 1, col: "col-md-4" },
  { name: "start_time", label: "Opens at", type: "datetime", col: "col-md-4", help: "Leave empty to open when you click ‘Go live’." },
  { name: "end_time", label: "Closes at", type: "datetime", col: "col-md-4", validate: (v, all) => (v && all.start_time && new Date(v) <= new Date(all.start_time) ? "Closing time must be after the opening time." : "") },
  { name: "pass_percentage", label: "Pass percentage", type: "number", min: 0, max: 100, col: "col-md-4" },
  { name: "shuffle_questions", label: "Shuffle questions", type: "checkbox", col: "col-md-3" },
  { name: "shuffle_options", label: "Shuffle options", type: "checkbox", col: "col-md-3" },
  { name: "negative_marking", label: "Negative marking", type: "checkbox", col: "col-md-3" },
  { name: "show_result_immediately", label: "Show result after submit", type: "checkbox", col: "col-md-3" },
  { name: "description", label: "Description", type: "textarea", rows: 2 },
  { name: "instructions", label: "Instructions for students", type: "textarea", rows: 4, placeholder: "Read all questions carefully…" },
];

if (document.body.dataset.page === "exams") App.init({ roles: App.STAFF }).then((user) => {
  const STATUS = ["draft", "scheduled", "live", "completed", "archived"].map((s) => ({ value: s, label: s[0].toUpperCase() + s.slice(1) }));
  new CrudPage("#app", {
    table: "exams", title: "Exams", icon: "pencil-square", singular: "exam", createLabel: "Create exam",
    subtitle: "Create an exam, add questions, assign it to batches, then publish",
    columns: [
      { key: "title", label: "Exam", render: (r) => `<a class="fw-semibold text-decoration-none" href="exam-edit.html?id=${r.id}">${UI.esc(r.title)}</a><div class="small text-secondary">${UI.esc(r.exam_category?.name || "")} ${r.organization ? "· " + UI.esc(r.organization.name) : ""}</div>` },
      { key: "total_questions", label: "Questions", render: (r) => `${r.total_questions || 0} <span class="text-secondary small">(${UI.num(r.total_marks)} marks)</span>` },
      { key: "duration_minutes", label: "Duration", render: (r) => (r.duration_minutes ? `${r.duration_minutes} min` : "—") },
      { key: "start_time", label: "Window", render: (r) => `<div class="small">${UI.fmtDateTime(r.start_time)}</div><div class="small text-secondary">${r.end_time ? "to " + UI.fmtDateTime(r.end_time) : ""}</div>` },
      { key: "status", label: "Status", render: (r) => UI.badge(r.status) },
    ],
    filters: [{ name: "status", label: "Status", options: STATUS }, { name: "exam_category_id", label: "Category", options: () => App.options("exam_categories") }],
    defaults: () => ({ organization_id: user.organization_id || "", duration_minutes: 60, attempt_limit: 1, pass_percentage: 33, show_result_immediately: true }),
    fields: window.EXAM_FIELDS(user),
    deleteWarning: "All questions links, assignments, attempts and results of this exam will be deleted too.",
    afterSave: (row, isNew) => { if (isNew) location.href = `exam-edit.html?id=${row.id}&new=1`; },
    canCreate: false,
    headerActions: [{ label: "Create exam (6-step wizard)", icon: "magic", class: "btn-primary", onClick: () => (location.href = "exam-wizard.html") }],
    rowActions: [
      { icon: "magic", label: "Open in wizard", class: "btn-light text-primary", show: (r) => ["draft", "scheduled"].includes(r.status), onClick: (r) => (location.href = `exam-wizard.html?id=${r.id}&step=3`) },
      { icon: "gear", text: "Manage", label: "Manage exam", class: "btn-outline-primary", onClick: (r) => (location.href = `exam-edit.html?id=${r.id}`) },
      { icon: "copy", label: "Duplicate", onClick: async (r, p) => { const res = await UI.run(() => API.call("exam.duplicate", { exam_id: r.id })); if (res) p.reload(); } },
    ],
    canEdit: false,
  });
});
