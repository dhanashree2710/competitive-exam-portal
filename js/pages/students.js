/* Students – full student records (students table, linked to users, batches, organizations and results) */
App.init({ roles: App.STAFF }).then(async (user) => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  const canEdit = App.isAdmin();
  const multiOrg = ["super_admin", "college_admin"].includes(user.role);
  const state = { page: 1, pageSize: 15, search: UI.qs("q") || "", filters: Object.fromEntries(["batch_id", "status", "fee_status", "organization_id"].filter((k) => UI.qs(k)).map((k) => [k, UI.qs(k)])) };
  const dash = (v) => (v === null || v === undefined || v === "" ? '<span class="text-secondary">—</span>' : esc(v));
  const inr = (v) => (v === null || v === undefined || v === "" ? "—" : "₹" + Number(v).toLocaleString("en-IN"));
  const feeBadge = (s) => ({ paid: '<span class="badge bg-success-subtle text-success-emphasis">Paid</span>', partial: '<span class="badge bg-warning-subtle text-warning-emphasis">Partly paid</span>',
    pending: '<span class="badge bg-danger-subtle text-danger-emphasis">Pending</span>' })[s] || dash(s);
  const statusBadge = (s) => ({ active: '<span class="badge bg-primary-subtle text-primary-emphasis">Active</span>', on_hold: '<span class="badge bg-secondary-subtle text-secondary-emphasis">On hold</span>',
    left: '<span class="badge bg-dark-subtle text-dark-emphasis">Left</span>', completed: '<span class="badge bg-info-subtle text-info-emphasis">Completed</span>' })[s] || dash(s);
  const gender = (g) => ({ male: "Male", female: "Female", other: "Other" })[g] || "";

  el.innerHTML = `
    <div class="page-head mb-3"><div><h1 class="page-title"><i class="bi bi-mortarboard me-2 text-primary"></i>${user.role === "faculty" ? "My students" : "Students"}</h1>
      <div class="text-secondary small">Full student records – personal, family, academic and fee details, linked to batches and results.</div></div>
      <div class="ms-auto d-flex flex-wrap gap-2">
        <div class="btn-group"><button class="btn btn-outline-secondary" data-x="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Excel</button><button class="btn btn-outline-secondary" data-x="csv"><i class="bi bi-filetype-csv me-1"></i>CSV</button></div>
        ${canEdit ? `<button class="btn btn-outline-light" id="impBtn"><i class="bi bi-upload me-1"></i>Import students</button><button class="btn btn-primary" id="addBtn"><i class="bi bi-person-plus me-1"></i>Add student</button>` : ""}</div></div>
    <div class="row g-3 mb-3" id="tiles"></div>
    <div class="card">
      <div class="toolbar-bar">
        <div class="search-box"><i class="bi bi-search"></i><input class="form-control" id="q" placeholder="Name, roll no., admission no., phone, area, parent…" aria-label="Search students">
          <button type="button" class="sb-clear d-none" id="qx" aria-label="Clear search"><i class="bi bi-x-lg"></i></button></div>
        <div class="tb-filters">
          ${multiOrg ? `<label class="tb-select"><span>Organization</span><select class="form-select" data-f="organization_id"><option value="">All</option></select></label>` : ""}
          <label class="tb-select"><span>Batch</span><select class="form-select" data-f="batch_id"><option value="">All</option></select></label>
          <label class="tb-select"><span>Status</span><select class="form-select" data-f="status"><option value="">All</option><option value="active">Active</option><option value="on_hold">On hold</option><option value="left">Left</option><option value="completed">Completed</option></select></label>
          <label class="tb-select"><span>Fees</span><select class="form-select" data-f="fee_status"><option value="">All</option><option value="paid">Paid</option><option value="partial">Partly paid</option><option value="pending">Pending</option></select></label>
        </div>
        <button type="button" class="tb-reset d-none" id="reset"><i class="bi bi-x-circle me-1"></i>Clear</button>
      </div>
      <div class="table-responsive"><table class="table table-hover align-middle mb-0">
        <thead><tr><th>Student</th><th>Roll / Admission</th><th>Batch</th><th>Gender · Age</th><th>Parent · Area</th><th>Fees</th><th class="text-end">Avg score</th><th>Status</th><th class="text-end">Actions</th></tr></thead>
        <tbody id="rows" class="fade-rows"></tbody></table></div>
      <div class="card-footer bg-white d-flex flex-wrap align-items-center gap-2 small" id="pager"></div>
    </div>`;

  // ---------- filters ----------
  (async () => {
    try {
      const batches = await App.lookup("batches");
      document.querySelector("[data-f=batch_id]").innerHTML += batches.map((b) => `<option value="${b.id}">${esc(b.name)}</option>`).join("");
      if (multiOrg) {
        const orgs = await App.lookup("organizations");
        document.querySelector("[data-f=organization_id]").innerHTML += orgs.filter((o) => o.type !== "root").map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join("");
      }
    } catch (e) { /* filters are optional */ }
    document.querySelectorAll("[data-f]").forEach((x) => { if (state.filters[x.dataset.f]) { x.value = state.filters[x.dataset.f]; x.closest(".tb-select").classList.add("on"); } });
    if (state.search) { document.getElementById("q").value = state.search; document.getElementById("qx").classList.remove("d-none"); }
    syncReset();
  })();
  const syncReset = () => document.getElementById("reset").classList.toggle("d-none", !(state.search || Object.values(state.filters).some(Boolean)));
  document.querySelectorAll("[data-f]").forEach((s) => s.addEventListener("change", () => { state.filters[s.dataset.f] = s.value; s.closest(".tb-select").classList.toggle("on", !!s.value); state.page = 1; load(); syncReset(); }));
  const q = document.getElementById("q"), qx = document.getElementById("qx");
  q.addEventListener("input", UI.debounce((e) => { state.search = e.target.value.trim(); state.page = 1; load(); syncReset(); }));
  q.addEventListener("input", () => qx.classList.toggle("d-none", !q.value));
  qx.onclick = () => { q.value = ""; qx.classList.add("d-none"); state.search = ""; state.page = 1; load(); syncReset(); };
  document.getElementById("reset").onclick = () => { q.value = ""; qx.classList.add("d-none"); state.search = ""; state.filters = {};
    document.querySelectorAll("[data-f]").forEach((s) => { s.value = ""; s.closest(".tb-select").classList.remove("on"); }); state.page = 1; load(); syncReset(); };

  // ---------- list ----------
  let last = null;
  async function load() {
    const tb = document.getElementById("rows");
    tb.innerHTML = `<tr><td colspan="9" class="text-center py-4"><div class="loader-ring mx-auto"></div></td></tr>`;
    try {
      const filters = Object.fromEntries(Object.entries(state.filters).filter(([, v]) => v));
      last = await API.call("student.list", { page: state.page, pageSize: state.pageSize, search: state.search, filters });
    } catch (e) { tb.innerHTML = `<tr><td colspan="9">${UI.empty(e.message, "exclamation-circle")}</td></tr>`; return; }
    const s = last.summary || {};
    document.getElementById("tiles").innerHTML = [
      ["people-fill", "Students", s.total, "g1"], ["check2-circle", "Active", s.active, "g3"],
      ["gender-female", "Girls · Boys", `${s.female || 0} · ${s.male || 0}`, "g2"], ["currency-rupee", "Fees pending", s.fee_pending, "g4"],
    ].map(([i, l, v, g]) => `<div class="col-6 col-lg-3"><div class="kpi ${{ g1: "k1", g3: "k3", g2: "k5", g4: "k4" }[g]} cursor-pointer" data-tile="${g}" title="Show these students"><div class="kpi-icon"><i class="bi bi-${i}"></i></div><div class="kpi-val">${esc(v ?? 0)}</div><div class="kpi-lbl">${l}</div></div></div>`).join("");
    document.querySelectorAll("[data-tile]").forEach((t) => (t.onclick = () => {
      const f = { g1: {}, g3: { status: "active" }, g2: {}, g4: { fee_status: "pending" } }[t.dataset.tile];
      state.filters = { ...f }; state.page = 1;
      document.querySelectorAll("[data-f]").forEach((x) => { x.value = state.filters[x.dataset.f] || ""; x.closest(".tb-select").classList.toggle("on", !!x.value); });
      syncReset(); load();
    }));
    tb.innerHTML = last.rows.length ? last.rows.map((r) => `<tr>
        <td><a href="#" class="d-flex align-items-center gap-2 text-decoration-none text-body" data-view="${r.id}"><span class="avatar">${r.avatar_url ? `<img src="${esc(r.avatar_url)}" alt="">` : esc(UI.initials(r.full_name))}</span>
          <div class="min-w-0"><div class="fw-semibold text-truncate">${esc(r.full_name)}</div><div class="small text-secondary text-truncate">${esc(r.email)}</div></div></a></td>
        <td><div class="small fw-semibold">${dash(r.roll_number)}</div><div class="small text-secondary">${dash(r.admission_no)}</div></td>
        <td class="small text-nowrap">${r.batch ? esc(r.batch.name.replace(" 2027 – ", " · ").replace("Batch ", "")) : dash("")}${r.batches.length > 1 ? `<span class="badge text-bg-light ms-1">+${r.batches.length - 1}</span>` : ""}</td>
        <td class="small">${gender(r.gender) || "—"}${r.age ? ` · ${r.age} yrs` : ""}</td>
        <td class="small"><div class="text-nowrap">${dash(r.father_name || r.mother_name)}</div><div class="text-secondary text-nowrap">${dash(r.father_phone || r.mother_phone)} · ${dash((r.address_line || "").split(", ").pop() || r.city)}</div></td>
        <td>${feeBadge(r.fee_status)}</td>
        <td class="text-end small">${r.avg_percent !== null && r.avg_percent !== undefined ? `<b>${r.avg_percent}%</b><div class="text-secondary">${r.exams_taken} exam${r.exams_taken === 1 ? "" : "s"}</div>` : '<span class="text-secondary">No exams</span>'}</td>
        <td>${statusBadge(r.status)}${r.is_active === false ? ' <span class="badge text-bg-secondary">Login off</span>' : ""}</td>
        <td class="text-end text-nowrap"><button class="btn btn-sm btn-light" data-view="${r.id}" title="View full record"><i class="bi bi-eye"></i></button>
          ${canEdit ? `<button class="btn btn-sm btn-light" data-edit="${r.id}" title="Edit"><i class="bi bi-pencil"></i></button><button class="btn btn-sm btn-light text-danger" data-del="${r.id}" title="Delete"><i class="bi bi-trash"></i></button>` : ""}</td>
      </tr>`).join("") : `<tr><td colspan="9">${UI.empty(state.search || Object.values(state.filters).some(Boolean) ? "No students match your search." : "No students yet.", "mortarboard")}</td></tr>`;
    const pages = Math.max(1, Math.ceil(last.total / state.pageSize));
    document.getElementById("pager").innerHTML = `<span class="text-secondary">${last.total} student${last.total === 1 ? "" : "s"} · page ${state.page} of ${pages}</span>
      <div class="ms-auto btn-group"><button class="btn btn-sm btn-light" data-pg="-1" ${state.page <= 1 ? "disabled" : ""}><i class="bi bi-chevron-left"></i> Previous</button>
      <button class="btn btn-sm btn-light" data-pg="1" ${state.page >= pages ? "disabled" : ""}>Next <i class="bi bi-chevron-right"></i></button></div>`;
  }
  document.getElementById("addBtn")?.addEventListener("click", () => edit(null));
  document.getElementById("impBtn")?.addEventListener("click", () => importStudents());
  el.addEventListener("click", (e) => {
    const v = e.target.closest("[data-view]"), ed = e.target.closest("[data-edit]"), d = e.target.closest("[data-del]"), pg = e.target.closest("[data-pg]");
    if (v) { e.preventDefault(); view(v.dataset.view); }
    else if (ed) edit(ed.dataset.edit);
    else if (d) remove(d.dataset.del);
    else if (pg) { state.page += Number(pg.dataset.pg); load(); }
  });

  // ---------- full record ----------
  async function view(id) {
    let d; try { d = await API.call("student.get", { id }); } catch (e) { return UI.handle(e); }
    const s = d.student, en = d.engagement || {};
    const row = (k, v) => `<div class="col-sm-6 col-lg-4"><div class="info-cell"><span>${k}</span><b>${v}</b></div></div>`;
    const body = `
      <div class="profile-head mb-3"><span class="avatar avatar-lg">${s.avatar_url ? `<img src="${esc(s.avatar_url)}" alt="">` : esc(UI.initials(s.full_name))}</span>
        <div class="min-w-0"><h4 class="mb-0">${esc(s.full_name)}</h4><div class="text-secondary small">${esc(s.email)} · ${esc(s.phone || "no phone")}</div>
        <div class="mt-1 d-flex flex-wrap gap-1">${statusBadge(s.status)} ${feeBadge(s.fee_status)} ${s.batches.map((b) => `<span class="badge text-bg-light">${esc(b.name)}</span>`).join(" ")}</div></div>
        <div class="ms-auto text-end small"><div class="text-secondary">Engagement</div><div class="fs-4 fw-bold">${en.score ?? "—"}</div><div>${esc(en.level || "")}</div></div></div>
      <ul class="nav nav-tabs mb-3" role="tablist">
        ${["Personal", "Family", "Academic", "Fees", "Performance"].map((t, i) => `<li class="nav-item"><button class="nav-link ${i ? "" : "active"}" data-bs-toggle="tab" data-bs-target="#st_${i}" type="button">${t}</button></li>`).join("")}</ul>
      <div class="tab-content">
        <div class="tab-pane fade show active" id="st_0"><div class="row g-2">
          ${row("Roll number", dash(s.roll_number))}${row("Admission number", dash(s.admission_no))}${row("Admission date", UI.fmtDate(s.admission_date))}
          ${row("Date of birth", s.date_of_birth ? `${UI.fmtDate(s.date_of_birth)} (${s.age} yrs)` : "—")}${row("Gender", gender(s.gender) || "—")}${row("Blood group", dash(s.blood_group))}
          ${row("Category", dash(s.category))}${row("Nationality", dash(s.nationality))}${row("Alternate phone", dash(s.alt_phone))}
          <div class="col-12"><div class="info-cell"><span>Address</span><b>${dash([s.address_line, s.city, s.state, s.pincode].filter(Boolean).join(", "))}</b></div></div>
          ${row("Organization", dash(s.organization?.name))}${row("Target exam", dash(s.exam_category?.name))}${row("Last sign-in", s.last_login_at ? UI.timeAgo(s.last_login_at) : "Never")}
        </div></div>
        <div class="tab-pane fade" id="st_1"><div class="row g-2">
          ${row("Father's name", dash(s.father_name))}${row("Father's phone", dash(s.father_phone))}${row("Father's occupation", dash(s.father_occupation))}
          ${row("Mother's name", dash(s.mother_name))}${row("Mother's phone", dash(s.mother_phone))}${row("Guardian email", dash(s.guardian_email))}
        </div></div>
        <div class="tab-pane fade" id="st_2"><div class="row g-2">
          ${row("School / college", dash(s.school_name))}${row("Board", dash(s.board))}${row("Passing year", dash(s.passing_year))}
          ${row("Class 10 %", s.class_10_percent ? s.class_10_percent + "%" : "—")}${row("Class 12 %", s.class_12_percent ? s.class_12_percent + "%" : "—")}${row("Main batch", dash(s.batch?.name))}
          ${s.notes ? `<div class="col-12"><div class="info-cell"><span>Notes</span><b>${esc(s.notes)}</b></div></div>` : ""}
        </div></div>
        <div class="tab-pane fade" id="st_3"><div class="row g-2">
          ${row("Total fee", inr(s.fee_total))}${row("Paid", inr(s.fee_paid))}${row("Balance due", inr(s.fee_due))}${row("Fee status", feeBadge(s.fee_status))}
        </div></div>
        <div class="tab-pane fade" id="st_4">
          <h6 class="mb-2">Exam results</h6>
          ${d.results.length ? `<div class="table-responsive mb-3"><table class="table table-sm"><thead><tr><th>Exam</th><th class="text-end">Marks</th><th class="text-end">%</th><th class="text-end">Rank</th><th>Date</th></tr></thead><tbody>
            ${d.results.map((r) => `<tr><td><a href="result-view.html?exam=${r.exam_id}&user=${s.id}">${esc(r.title)}</a></td><td class="text-end">${r.score} / ${r.max}</td><td class="text-end">${r.percentage}%</td><td class="text-end">${r.rank ?? "—"}</td><td>${UI.fmtDate(r.date)}</td></tr>`).join("")}</tbody></table></div>`
            : `<p class="text-secondary small">No exams taken yet.</p>`}
          <h6 class="mb-2">Assignments</h6>
          ${d.assignments.length ? `<div class="table-responsive"><table class="table table-sm"><thead><tr><th>Assignment</th><th>Status</th><th class="text-end">Marks</th><th>Submitted</th></tr></thead><tbody>
            ${d.assignments.map((a) => `<tr><td>${esc(a.title)}</td><td>${UI.badge(a.status)}</td><td class="text-end">${a.marks !== null ? `${a.marks} / ${a.max}` : "—"}</td><td>${UI.fmtDate(a.submitted_at)}</td></tr>`).join("")}</tbody></table></div>`
            : `<p class="text-secondary small">No submissions yet.</p>`}
        </div>
      </div>`;
    UI.modal({ title: "Student record", body, size: "xl",
      footer: `<a class="btn btn-light" href="insights.html?user=${s.id}"><i class="bi bi-graph-up-arrow me-1"></i>Insights</a>${canEdit ? `<button class="btn btn-primary" data-edit="${s.id}" data-bs-dismiss="modal"><i class="bi bi-pencil me-1"></i>Edit</button>` : ""}<button class="btn btn-light" data-bs-dismiss="modal">Close</button>` });
    document.querySelector(".modal.show [data-edit], .modal [data-edit]")?.addEventListener("click", () => setTimeout(() => edit(s.id), 300));
  }

  // ---------- add / edit ----------
  async function edit(id) {
    let s = {};
    if (id) { try { s = (await API.call("student.get", { id })).student; } catch (e) { return UI.handle(e); } }
    const orgOpts = () => App.options("organizations", {}, (o) => o.name).then((x) => x);
    const batchOpts = async (v) => (await App.lookup("batches")).filter((b) => !v.organization_id || !b.organization_id || b.organization_id === v.organization_id || b.organization?.id === v.organization_id)
      .map((b) => ({ value: b.id, label: b.name }));
    const catOpts = () => App.options("exam_categories");
    const pw = (v) => (v && (v.length < 8 || !/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) ? "Use at least 8 characters with letters and numbers." : "");
    const phone = (v) => (v && !/^(\+?91[\s-]?)?[6-9]\d{9}$/.test(v.replace(/[\s-]/g, "")) ? "Enter a valid 10-digit mobile number." : "");
    const pct = (v) => (v !== "" && v !== null && v !== undefined && (Number(v) < 0 || Number(v) > 100) ? "Enter a value between 0 and 100." : "");
    const values = { ...s, organization_id: s.organization?.id || user.organization_id || "", exam_category_id: s.exam_category?.id || "",
      batch_ids: (s.batches || []).map((b) => b.id), is_active: s.is_active ?? true, status: s.status || "active", nationality: s.nationality || "Indian", state: s.state || "Maharashtra", city: s.city || "Pune" };
    const fields = [
      { type: "section", name: "_s1", label: "Login & enrolment", icon: "person-badge" },
      { name: "full_name", label: "Full name", required: true },
      { name: "email", label: "Email (used to sign in)", type: "email", required: true },
      { name: "phone", label: "Mobile number", type: "tel", validate: phone },
      { name: "password", label: id ? "New password (leave empty to keep)" : "Password", type: "password", required: !id, validate: pw, help: "At least 8 characters with letters and numbers." },
      ...(multiOrg ? [{ name: "organization_id", label: "Organization", type: "select", required: true, options: orgOpts }] : []),
      { name: "batch_ids", label: "Batches", type: "multiselect", size: 4, options: batchOpts, watch: ["organization_id"] },
      { name: "roll_number", label: "Roll number", placeholder: "e.g. SIIT/JEE/27/051" },
      { name: "admission_no", label: "Admission number", placeholder: "e.g. SIIT/2026/0121" },
      { name: "admission_date", label: "Admission date", type: "date" },
      { name: "exam_category_id", label: "Target exam", type: "select", options: catOpts },
      { name: "status", label: "Student status", type: "select", options: [{ value: "active", label: "Active" }, { value: "on_hold", label: "On hold" }, { value: "left", label: "Left" }, { value: "completed", label: "Completed" }] },
      { name: "is_active", label: "Login enabled", type: "checkbox" },
      { type: "section", name: "_s2", label: "Personal details", icon: "person-vcard" },
      { name: "date_of_birth", label: "Date of birth", type: "date" },
      { name: "gender", label: "Gender", type: "select", options: [{ value: "female", label: "Female" }, { value: "male", label: "Male" }, { value: "other", label: "Other" }] },
      { name: "blood_group", label: "Blood group", type: "select", options: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"] },
      { name: "category", label: "Category", type: "select", options: ["General", "OBC", "SC", "ST", "EWS", "Other"] },
      { name: "nationality", label: "Nationality" },
      { name: "alt_phone", label: "Alternate phone", type: "tel", validate: phone },
      { name: "address_line", label: "Address", col: "col-12", placeholder: "Flat / house, building, road, area" },
      { name: "city", label: "City" }, { name: "state", label: "State" },
      { name: "pincode", label: "PIN code", validate: (v) => (v && !/^[1-9]\d{5}$/.test(v) ? "Enter a 6-digit PIN code." : "") },
      { type: "section", name: "_s3", label: "Parents / guardian", icon: "people" },
      { name: "father_name", label: "Father's name" }, { name: "father_phone", label: "Father's phone", type: "tel", validate: phone },
      { name: "father_occupation", label: "Father's occupation" }, { name: "mother_name", label: "Mother's name" },
      { name: "mother_phone", label: "Mother's phone", type: "tel", validate: phone }, { name: "guardian_email", label: "Guardian email", type: "email" },
      { type: "section", name: "_s4", label: "Academic background", icon: "book" },
      { name: "school_name", label: "School / college" },
      { name: "board", label: "Board", type: "select", options: ["CBSE", "ICSE", "Maharashtra State Board", "Other State Board", "University"] },
      { name: "class_10_percent", label: "Class 10 %", type: "number", min: 0, max: 100, validate: pct },
      { name: "class_12_percent", label: "Class 12 %", type: "number", min: 0, max: 100, validate: pct },
      { name: "passing_year", label: "Passing year", type: "number", min: 2000, max: 2035 },
      { type: "section", name: "_s5", label: "Fees", icon: "currency-rupee" },
      { name: "fee_total", label: "Total fee (₹)", type: "number", min: 0 },
      { name: "fee_paid", label: "Fee paid (₹)", type: "number", min: 0, help: "Fee status is worked out automatically." },
      { name: "notes", label: "Notes", type: "textarea", rows: 2 },
    ];
    await UI.formModal({
      title: id ? `Edit ${s.full_name}` : "Add student", fields, values, size: "xl", submitText: id ? "Save changes" : "Add student",
      onSubmit: async (v) => {
        const data = { ...v, id: id || undefined };
        if (!data.password) delete data.password;
        if (!multiOrg) delete data.organization_id;
        const r = await API.call("student.save", { data });
        UI.toast(r.message); App.clearLookup(); load();
        return r.row;
      },
    });
  }

  async function remove(id) {
    const r = last.rows.find((x) => x.id === id);
    if (!(await UI.confirm(`${r ? r.full_name + "'s" : "This"} login and full student record will be deleted. Students with exam or assignment history can't be deleted – set their status to "Left" instead.`, { title: "Delete student?", confirmText: "Delete", danger: true }))) return;
    const ok = await UI.run(() => API.call("crud.delete", { table: "users", id }), { loading: "Deleting…" });
    if (ok) load();
  }


  // ---------- import many students (Excel / CSV) → users + students + batches, with logins ----------
  const COLS = ["full_name", "email", "password", "phone", "roll_number", "admission_no", "batch", "admission_date", "date_of_birth", "gender", "blood_group", "category",
    "address_line", "city", "state", "pincode", "alt_phone", "father_name", "father_phone", "father_occupation", "mother_name", "mother_phone", "guardian_email",
    "school_name", "board", "class_10_percent", "class_12_percent", "passing_year", "fee_total", "fee_paid"];
  const ALIAS = { name: "full_name", "student name": "full_name", "full name": "full_name", "email id": "email", "login id": "email", "login": "email", "e-mail": "email", mail: "email",
    mobile: "phone", "mobile no": "phone", "phone no": "phone", contact: "phone", "roll no": "roll_number", roll: "roll_number", "roll number": "roll_number",
    "admission no": "admission_no", "admission number": "admission_no", "batch name": "batch", "batch code": "batch", dob: "date_of_birth", "date of birth": "date_of_birth", "birth date": "date_of_birth",
    sex: "gender", "blood group": "blood_group", caste: "category", address: "address_line", pin: "pincode", "pin code": "pincode", "father name": "father_name", father: "father_name",
    "father mobile": "father_phone", "father phone": "father_phone", "mother name": "mother_name", mother: "mother_name", "mother mobile": "mother_phone", "mother phone": "mother_phone",
    "parent email": "guardian_email", school: "school_name", college: "school_name", "10th %": "class_10_percent", "10th": "class_10_percent", "12th %": "class_12_percent", "12th": "class_12_percent",
    "total fee": "fee_total", fees: "fee_total", "fee paid": "fee_paid", paid: "fee_paid", pass: "password" };
  const norm = (h) => { const k = String(h || "").trim().toLowerCase().replace(/[_.]+/g, " ").replace(/\s+/g, " "); const u = k.replace(/ /g, "_"); return COLS.includes(u) ? u : ALIAS[k] || u; };
  const SAMPLE = [["Riya Sharma", "riya.sharma@example.com", "", "9876543210", "SIIT/JEE/27/101", "SIIT/2026/0501", "JEE27A", "2026-06-01", "2009-03-14", "Female", "B+", "General",
    "Flat 12, Sai Residency, ITI Road, Aundh", "Pune", "Maharashtra", "411007", "", "Sunil Sharma", "9822012345", "Engineer", "Anita Sharma", "9822054321", "sunil.sharma@example.com",
    "Modern Junior College", "CBSE", "91.4", "", "2027", "95000", "50000"]];

  async function importStudents() {
    const batches = await App.lookup("batches").catch(() => []);
    const orgs = multiOrg ? (await App.lookup("organizations").catch(() => [])).filter((o) => o.type !== "root") : [];
    let rows = [], results = null;
    const m = UI.modal({ title: "Import students", size: "xl", body: "" , footer: `<button class="btn btn-light" data-bs-dismiss="modal">Close</button>` });
    const opt = { organization_id: multiOrg ? (orgs[0]?.id || "") : user.organization_id, batch_id: "", password_mode: "generate", default_password: "", update_existing: true };
    const step1 = () => {
      m.body.innerHTML = `
        <div class="import-steps mb-3"><span class="on">1 · File</span><span>2 · Check</span><span>3 · Logins</span></div>
        <div class="row g-3">
          <div class="col-lg-5"><div class="import-help h-100">
            <h6 class="fw-bold"><i class="bi bi-file-earmark-spreadsheet me-1"></i>1. Get the template</h6>
            <p class="small text-secondary mb-2">One row per student. Only <b>full_name</b> and <b>email</b> (the login ID) are required. The <b>batch</b> column takes a batch code or name. Dates as YYYY-MM-DD.</p>
            <div class="d-flex gap-2 flex-wrap mb-3"><button class="btn btn-sm btn-success" data-tpl="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Excel template</button>
              <button class="btn btn-sm btn-outline-secondary" data-tpl="csv"><i class="bi bi-filetype-csv me-1"></i>CSV template</button></div>
            <div class="small text-secondary"><b>Columns:</b> ${COLS.map((c) => `<code>${c}</code>`).join(" ")}</div>
            <div class="small text-secondary mt-2"><b>Your batches:</b> ${batches.map((b) => `<span class="chip">${esc(b.code || b.name)}</span>`).join(" ") || "none yet"}</div>
          </div></div>
          <div class="col-lg-7"><div class="row g-3">
            ${multiOrg ? `<div class="col-md-6"><label class="form-label">Organization</label><select class="form-select" id="iOrg">${orgs.map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join("")}</select></div>` : ""}
            <div class="col-md-6"><label class="form-label">Batch for rows without one</label><select class="form-select" id="iBatch"><option value="">— None —</option>${batches.map((b) => `<option value="${b.id}">${esc(b.name)}</option>`).join("")}</select></div>
            <div class="col-12"><label class="form-label">Login passwords</label>
              <div class="d-flex flex-column gap-1">
                <label class="form-check"><input class="form-check-input" type="radio" name="pm" value="generate" checked> <span class="form-check-label">Create a password for each student (e.g. <code>Riya@4821</code>) – unless the file has a password</span></label>
                <label class="form-check"><input class="form-check-input" type="radio" name="pm" value="default"> <span class="form-check-label">Same password for everyone</span></label></div>
              <input class="form-control mt-2 d-none" id="iPw" placeholder="At least 8 characters with letters and numbers"></div>
            <div class="col-12"><label class="form-check"><input class="form-check-input" type="checkbox" id="iUpd" checked> <span class="form-check-label">If a student with the same email already exists, update their details</span></label></div>
            <div class="col-12"><label class="upload-drop" id="drop"><input type="file" accept=".xlsx,.xls,.csv" hidden id="iFile">
              <i class="bi bi-cloud-arrow-up"></i><b>Choose the Excel or CSV file</b><span class="small text-secondary">or drag & drop it here</span></label></div>
          </div></div>
        </div>`;
      m.body.querySelectorAll("[name=pm]").forEach((r) => (r.onchange = () => m.body.querySelector("#iPw").classList.toggle("d-none", r.value !== "default" || !r.checked)));
      m.body.querySelectorAll("[data-tpl]").forEach((b) => (b.onclick = () => (b.dataset.tpl === "csv" ? Exporter.csv("Student import template", COLS, SAMPLE) : UI.run(() => Exporter.xlsx("Student import template", COLS, SAMPLE), { loading: "Preparing…", success: false }))));
      const take = async (file) => {
        if (!file) return;
        opt.organization_id = multiOrg ? m.body.querySelector("#iOrg").value : user.organization_id;
        opt.batch_id = m.body.querySelector("#iBatch").value; opt.password_mode = m.body.querySelector("[name=pm]:checked").value;
        opt.default_password = m.body.querySelector("#iPw").value; opt.update_existing = m.body.querySelector("#iUpd").checked;
        if (opt.password_mode === "default" && (opt.default_password.length < 8 || !/[A-Za-z]/.test(opt.default_password) || !/\d/.test(opt.default_password)))
          return UI.warn("The common password needs at least 8 characters with letters and numbers.");
        let raw; try { UI.loading(true, "Reading the file…"); raw = await Exporter.readRows(file); } catch (e) { return UI.handle(e); } finally { UI.loading(false); }
        rows = raw.map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k === "_line" ? k : norm(k), v])));
        if (!rows.length) return UI.warn("No student rows were found in this file.");
        if (rows.length > 2000) return UI.warn("Please import at most 2000 students at a time.");
        step2();
      };
      const fi = m.body.querySelector("#iFile"), drop = m.body.querySelector("#drop");
      fi.onchange = () => take(fi.files[0]);
      drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
      drop.addEventListener("dragleave", () => drop.classList.remove("over"));
      drop.addEventListener("drop", (e) => { e.preventDefault(); drop.classList.remove("over"); take(e.dataTransfer.files[0]); });
    };
    const step2 = () => {
      const bad = rows.filter((r) => !r.full_name || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(r.email || ""));
      const shown = COLS.filter((c) => rows.some((r) => r[c])).slice(0, 9);
      m.body.innerHTML = `<div class="import-steps mb-3"><span class="done">1 · File</span><span class="on">2 · Check</span><span>3 · Logins</span></div>
        <div class="d-flex flex-wrap gap-2 align-items-center mb-2"><span class="chip chip-published">${rows.length} rows</span>
          ${bad.length ? `<span class="chip chip-closed">${bad.length} missing name or email – they will be skipped</span>` : `<span class="chip chip-completed">All rows have a name and email</span>`}
          <span class="small text-secondary ms-auto">Showing the first ${Math.min(rows.length, 50)} rows</span></div>
        <div class="table-responsive border rounded-3" style="max-height:48vh"><table class="table table-sm mb-0"><thead><tr><th>Line</th>${shown.map((c) => `<th>${esc(c.replace(/_/g, " "))}</th>`).join("")}</tr></thead>
        <tbody>${rows.slice(0, 50).map((r) => `<tr class="${!r.full_name || !/@/.test(r.email || "") ? "table-danger" : ""}"><td class="text-secondary">${r._line ?? ""}</td>${shown.map((c) => `<td class="small text-nowrap">${esc(r[c] || "")}</td>`).join("")}</tr>`).join("")}</tbody></table></div>
        <div class="d-flex gap-2 mt-3"><button class="btn btn-light" id="iBack"><i class="bi bi-arrow-left me-1"></i>Choose another file</button>
          <button class="btn btn-primary ms-auto" id="iGo"><i class="bi bi-person-plus me-1"></i>Import ${rows.length} student${rows.length === 1 ? "" : "s"}</button></div>`;
      m.body.querySelector("#iBack").onclick = step1;
      m.body.querySelector("#iGo").onclick = run;
    };
    const run = async () => {
      results = { created: 0, updated: 0, failed: 0, rows: [] };
      try {
        for (let i = 0; i < rows.length; i += 50) {
          UI.loading(true, `Importing ${Math.min(i + 50, rows.length)} of ${rows.length}…`);
          const r = await API.call("student.import", { ...opt, batch_id: opt.batch_id || null, rows: rows.slice(i, i + 50) });
          results.created += r.created; results.updated += r.updated; results.failed += r.failed; results.rows.push(...r.rows);
        }
      } catch (e) { UI.handle(e); } finally { UI.loading(false); }
      App.clearLookup(); load(); step3();
    };
    const credCols = ["Line", "Name", "Login ID (email)", "Password", "Roll no.", "Admission no.", "Batch", "Result"];
    const credRows = () => results.rows.map((x) => [x.line, x.full_name, x.email, x.password || (x.ok ? "(unchanged)" : ""), x.roll_number || "", x.admission_no || "", x.batch || "", x.ok ? (x.action === "created" ? "Created" : "Updated") : "Not imported: " + x.message]);
    const step3 = () => {
      let onlyBad = false;
      const draw = () => {
        const list = results.rows.filter((x) => !onlyBad || !x.ok);
        m.body.querySelector("#iRes").innerHTML = list.map((x) => `<tr class="${x.ok ? "" : "table-danger"}"><td class="text-secondary">${x.line}</td><td class="fw-semibold">${esc(x.full_name || "")}</td>
          <td><code>${esc(x.email || "")}</code></td><td>${x.password ? `<code class="pw">${esc(x.password)}</code>` : x.ok ? '<span class="small text-secondary">unchanged</span>' : ""}</td>
          <td class="small">${esc(x.roll_number || "")}</td><td class="small">${esc(x.batch || "")}</td>
          <td>${x.ok ? `<span class="chip ${x.action === "created" ? "chip-completed" : "chip-published"}">${x.action === "created" ? "Created" : "Updated"}</span>` : `<span class="small text-danger">${esc(x.message)}</span>`}</td></tr>`).join("") || `<tr><td colspan="7">${UI.empty("Nothing to show.", "check2-circle")}</td></tr>`;
      };
      m.body.innerHTML = `<div class="import-steps mb-3"><span class="done">1 · File</span><span class="done">2 · Check</span><span class="on">3 · Logins</span></div>
        <div class="row g-3 mb-3">${[["k3", "person-check", "Created", results.created], ["k1", "arrow-repeat", "Updated", results.updated], ["k6", "exclamation-triangle", "Not imported", results.failed]]
          .map(([k, i, l, v]) => `<div class="col-4"><div class="kpi ${k}"><div class="kpi-icon"><i class="bi bi-${i}"></i></div><div class="kpi-val">${v}</div><div class="kpi-lbl">${l}</div></div></div>`).join("")}</div>
        <div class="alert alert-warning small"><i class="bi bi-shield-lock me-1"></i>Download the login sheet now – passwords are shown only once. Students can change their password after signing in.</div>
        <div class="d-flex flex-wrap gap-2 mb-2"><button class="btn btn-success btn-sm" data-dl="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Download logins (Excel)</button>
          <button class="btn btn-outline-secondary btn-sm" data-dl="csv"><i class="bi bi-filetype-csv me-1"></i>CSV</button>
          <button class="btn btn-outline-danger btn-sm" data-dl="pdf"><i class="bi bi-file-earmark-pdf me-1"></i>PDF</button>
          <label class="form-check ms-auto small"><input class="form-check-input" type="checkbox" id="onlyBad"> <span class="form-check-label">Show only rows with problems</span></label></div>
        <div class="table-responsive border rounded-3" style="max-height:46vh"><table class="table table-sm align-middle mb-0"><thead><tr><th>Line</th><th>Name</th><th>Login ID</th><th>Password</th><th>Roll no.</th><th>Batch</th><th>Result</th></tr></thead><tbody id="iRes"></tbody></table></div>
        <div class="d-flex mt-3"><button class="btn btn-light" id="iAgain"><i class="bi bi-upload me-1"></i>Import another file</button></div>`;
      draw();
      m.body.querySelector("#onlyBad").onchange = (e) => { onlyBad = e.target.checked; draw(); };
      m.body.querySelector("#iAgain").onclick = step1;
      m.body.querySelectorAll("[data-dl]").forEach((b) => (b.onclick = () => {
        const t = "Student logins"; const f = b.dataset.dl;
        UI.run(async () => (f === "csv" ? Exporter.csv(t, credCols, credRows()) : Exporter[f](t, credCols, credRows())), { loading: "Preparing…", success: "Downloaded." });
      }));
      if (results.created + results.updated) UI.toast(`${results.created} created, ${results.updated} updated${results.failed ? `, ${results.failed} with problems` : ""}.`);
    };
    step1();
  }

  // ---------- export ----------
  document.querySelectorAll("[data-x]").forEach((b) => (b.onclick = async () => {
    const all = await UI.run(() => API.call("student.list", { page: 1, pageSize: 200, search: state.search, filters: Object.fromEntries(Object.entries(state.filters).filter(([, v]) => v)) }), { loading: "Preparing…", success: false });
    if (!all) return;
    const cols = ["Roll no.", "Admission no.", "Name", "Email", "Phone", "Batch", "Gender", "Date of birth", "Blood group", "Category", "Address", "City", "PIN", "Father", "Father phone", "Mother", "Mother phone", "School", "Board", "Class 10 %", "Class 12 %", "Total fee", "Paid", "Fee status", "Status", "Avg %"];
    const rows = all.rows.map((r) => [r.roll_number, r.admission_no, r.full_name, r.email, r.phone, r.batch?.name, gender(r.gender), r.date_of_birth, r.blood_group, r.category, r.address_line, r.city, r.pincode,
      r.father_name, r.father_phone, r.mother_name, r.mother_phone, r.school_name, r.board, r.class_10_percent, r.class_12_percent, r.fee_total, r.fee_paid, r.fee_status, r.status, r.avg_percent]);
    UI.run(() => (b.dataset.x === "csv" ? Promise.resolve(Exporter.csv("Students", cols, rows)) : Exporter.xlsx("Students", cols, rows)), { loading: "Preparing download…", success: "Download ready." });
  }));

  await load();
  const pre = UI.qs("id"); if (pre) view(pre);
});
