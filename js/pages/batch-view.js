/* Batch detail – everything about one batch: students, faculty, exams, results, assignments, activities and charts */
App.init({ roles: App.STAFF }).then(async (user) => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  const id = UI.qs("id");
  if (!id) { location.href = "batches.html"; return; }
  el.innerHTML = `<div class="text-center py-5"><div class="loader-ring mx-auto"></div><div class="text-secondary mt-2">Loading batch…</div></div>`;
  let d;
  try { d = await API.call("batch.detail", { batch_id: id }); }
  catch (e) { el.innerHTML = UI.empty(e.message, "exclamation-circle") + `<div class="text-center"><a class="btn btn-primary" href="batches.html">Back to batches</a></div>`; return; }
  const b = d.batch, st = d.stats, admin = App.isAdmin();
  document.title = `${b.name} · ${document.title.split("·").pop().trim()}`;
  const pct = (v) => (v === null || v === undefined ? "—" : `${v}%`);
  const lvlCls = { "Highly engaged": "lv-high", Engaged: "lv-ok", "At risk": "lv-risk", Inactive: "lv-off" };
  const statusChip = (s) => `<span class="chip chip-${s}">${esc({ live: "Live", scheduled: "Scheduled", completed: "Completed", draft: "Draft", archived: "Archived", published: "Open", closed: "Closed" }[s] || s)}</span>`;
  const bar = (v, cls = "") => `<div class="progress-slim ${cls}"><span style="width:${Math.max(0, Math.min(100, Number(v) || 0))}%"></span></div>`;

  el.innerHTML = `
  <section class="batch-hero mb-4">
    <div class="bh-pattern"></div>
    <div class="position-relative d-flex flex-wrap gap-3 align-items-start">
      <div class="bh-badge"><i class="bi bi-collection"></i></div>
      <div class="flex-grow-1 min-w-0">
        <div class="d-flex flex-wrap gap-2 mb-2">${b.code ? `<span class="hero-chip">${esc(b.code)}</span>` : ""}${b.exam_category ? `<span class="hero-chip"><i class="bi bi-bullseye me-1"></i>${esc(b.exam_category.name)}</span>` : ""}
          ${b.academic_year ? `<span class="hero-chip">${esc(b.academic_year)}</span>` : ""}<span class="hero-chip ${b.is_active ? "on" : ""}">${b.is_active ? "Active" : "Inactive"}</span></div>
        <h1 class="bh-title">${esc(b.name)}</h1>
        <div class="bh-sub"><i class="bi bi-building me-1"></i>${esc(b.organization?.name || "")}${b.start_date ? ` <span class="mx-2">•</span><i class="bi bi-calendar3 me-1"></i>${UI.fmtDate(b.start_date)} – ${UI.fmtDate(b.end_date)}` : ""}</div>
        ${b.description ? `<p class="bh-desc">${esc(b.description)}</p>` : ""}
      </div>
      <div class="d-flex flex-wrap gap-2 bh-actions">
        ${App.is("super_admin", "college_admin", "institute_admin", "faculty") ? `<a class="btn btn-light" href="exam-wizard.html"><i class="bi bi-plus-circle me-1"></i>New exam</a>
        <a class="btn btn-outline-light" href="assignments.html"><i class="bi bi-journal-plus me-1"></i>Assignment</a>` : ""}
        <button class="btn btn-outline-light" id="xBatch"><i class="bi bi-download me-1"></i>Export</button>
      </div>
    </div>
  </section>

  <div class="row g-3 mb-4 kpi-row">
    ${[["people-fill", "Students", st.students, `${st.active_7d} active this week`, "k1"], ["speedometer2", "Average score", pct(st.avg_percent), `${st.results} results`, "k2"],
       ["patch-check-fill", "Pass rate", pct(st.pass_rate), `${st.exams_completed} completed exam${st.exams_completed === 1 ? "" : "s"}`, "k3"],
       ["journal-check", "Submissions", pct(st.submission_rate), `${st.assignments} assignment${st.assignments === 1 ? "" : "s"}`, "k4"],
       ["card-checklist", "Exams", st.exams, `${st.exams_open} open / upcoming`, "k5"], ["currency-rupee", "Fees due", "₹" + Number(st.fee_due || 0).toLocaleString("en-IN"), `₹${Number(st.fee_collected || 0).toLocaleString("en-IN")} collected`, "k6"]]
      .map(([i, l, v, s, k]) => `<div class="col-6 col-md-4 col-xl-2"><div class="kpi ${k} cursor-pointer" data-go="${k}" title="Open the list"><div class="kpi-icon"><i class="bi bi-${i}"></i></div><div class="kpi-val">${esc(v)}</div><div class="kpi-lbl">${l}</div><div class="kpi-sub">${esc(s)}</div></div></div>`).join("")}
  </div>

  <div class="row g-3 mb-4">
    <div class="col-lg-6 col-xl-3"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-bar-chart-fill me-2"></i>Score distribution</div><div class="card-body"><div class="chart-box" id="cDist"></div></div></div></div>
    <div class="col-lg-6 col-xl-3"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-graph-up-arrow me-2"></i>Exam averages</div><div class="card-body"><div class="chart-box" id="cTrend"></div></div></div></div>
    <div class="col-lg-6 col-xl-3"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-bullseye me-2"></i>Subject strength</div><div class="card-body"><div class="chart-box" id="cSub"></div></div></div></div>
    <div class="col-lg-6 col-xl-3"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-activity me-2"></i>Engagement</div><div class="card-body"><div class="chart-box" id="cEng"></div></div></div></div>
  </div>

  <div class="card">
    <div class="card-header p-0 border-0"><ul class="nav nav-tabs nav-tabs-lg px-3 pt-2 flex-nowrap overflow-auto" id="bt">
      ${[["students", "people", "Students", d.students.length], ["exams", "card-checklist", "Exams", d.exams.length], ["assignments", "journal-check", "Assignments", d.assignments.length],
         ["faculty", "person-badge", "Faculty", d.faculty.length], ["activities", "lightning-charge", "Activities", d.activities.length], ["news", "megaphone", "Announcements", d.announcements.length]]
        .map(([k, i, l, n], x) => `<li class="nav-item"><button class="nav-link ${x ? "" : "active"} text-nowrap" data-tab="${k}"><i class="bi bi-${i} me-1"></i>${l} <span class="badge text-bg-light">${n}</span></button></li>`).join("")}
    </ul></div>
    <div id="tabBody"></div>
  </div>`;

  // ---------- charts ----------
  const ch = d.charts;
  Charts.draw("#cDist", { type: "bar", labels: (ch.distribution || []).map((x) => x.label), series: [{ label: "Students", data: (ch.distribution || []).map((x) => x.count), colors: ["#F43F5E", "#F59E0B", "#0EA5E9", "#2563EB", "#10B981"] }], empty: "No results yet" });
  Charts.draw("#cTrend", { type: "line", labels: ch.exam_trend.map((x) => x.label), series: [{ label: "Average", data: ch.exam_trend.map((x) => x.avg), color: "#2563EB" }], percent: true, empty: "No completed exams yet" });
  Charts.draw("#cSub", { type: ch.subjects.length >= 3 ? "radar" : "bar", labels: ch.subjects.map((x) => x.label), series: [{ label: "Average", data: ch.subjects.map((x) => x.avg), color: "#F97316" }], percent: true, empty: "No subject data yet", keepLabels: true });
  const lv = ["Highly engaged", "Engaged", "At risk", "Inactive"];
  Charts.draw("#cEng", { type: "doughnut", labels: lv, series: [{ label: "Students", data: lv.map((l) => ch.engagement[l] || 0), colors: ["#10B981", "#0EA5E9", "#F59E0B", "#F43F5E"] }], keepLabels: true });

  // ---------- tabs ----------
  const body = document.getElementById("tabBody");
  const tabs = {
    students() {
      body.innerHTML = `<div class="toolbar-bar"><div class="search-box"><i class="bi bi-search"></i><input class="form-control" id="sq" placeholder="Search students by name, roll number or email"></div>
        <div class="seg" id="sf">${["All", "Highly engaged", "Engaged", "At risk", "Inactive"].map((x, i) => `<button class="${i ? "" : "on"}" data-lv="${i ? x : ""}">${x}</button>`).join("")}</div></div>
        <div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead><tr><th>#</th><th>Student</th><th>Roll no.</th><th class="text-end">Exams</th><th style="min-width:150px">Average</th><th class="text-end">Best rank</th><th class="text-end">Submissions</th><th>Engagement</th><th>Fees</th><th></th></tr></thead><tbody id="sRows"></tbody></table></div>`;
      let lvF = "";
      const draw = () => {
        const q = (document.getElementById("sq").value || "").toLowerCase();
        const rows = d.students.filter((s) => (!q || `${s.full_name} ${s.roll_number || ""} ${s.email}`.toLowerCase().includes(q)) && (!lvF || s.engagement?.level === lvF));
        document.getElementById("sRows").innerHTML = rows.length ? rows.map((s, i) => `<tr>
          <td class="text-secondary small">${i + 1}</td>
          <td><a class="d-flex align-items-center gap-2 text-decoration-none text-body" href="students.html?id=${s.id}"><span class="avatar">${s.avatar_url ? `<img src="${esc(s.avatar_url)}" alt="">` : esc(UI.initials(s.full_name))}</span>
            <div class="min-w-0"><div class="fw-semibold">${esc(s.full_name)}</div><div class="small text-secondary">${esc(s.email)}</div></div></a></td>
          <td class="small">${esc(s.roll_number || "—")}</td><td class="text-end">${s.exams_taken}</td>
          <td>${s.avg_percent != null ? `<div class="d-flex align-items-center gap-2"><b class="small" style="width:44px">${s.avg_percent}%</b>${bar(s.avg_percent, s.avg_percent >= 70 ? "good" : s.avg_percent >= 40 ? "" : "low")}</div>` : '<span class="text-secondary small">No exams</span>'}</td>
          <td class="text-end">${s.best_rank ? `<span class="rank-pill">#${s.best_rank}</span>` : "—"}</td><td class="text-end">${s.submissions}</td>
          <td><span class="lv ${lvlCls[s.engagement?.level] || ""}">${esc(s.engagement?.level || "—")}</span></td>
          <td>${{ paid: '<span class="chip chip-completed">Paid</span>', partial: '<span class="chip chip-scheduled">Partly</span>', pending: '<span class="chip chip-closed">Pending</span>' }[s.fee_status] || "—"}</td>
          <td class="text-end"><a class="btn btn-sm btn-light" href="insights.html?user=${s.id}" title="Insights"><i class="bi bi-graph-up"></i></a></td></tr>`).join("")
          : `<tr><td colspan="10">${UI.empty("No students match.", "people")}</td></tr>`;
      };
      document.getElementById("sq").addEventListener("input", draw);
      document.querySelectorAll("#sf button").forEach((x) => (x.onclick = () => { document.querySelectorAll("#sf button").forEach((y) => y.classList.toggle("on", y === x)); lvF = x.dataset.lv; draw(); }));
      draw();
    },
    exams() {
      body.innerHTML = d.exams.length ? `<div class="row g-3 p-3">${d.exams.map((e) => `<div class="col-md-6 col-xl-4"><div class="exam-tile h-100">
        <div class="d-flex align-items-start gap-2 mb-2"><div class="fw-bold flex-grow-1">${esc(e.title)}</div>${statusChip(e.status)}</div>
        <div class="small text-secondary mb-3"><i class="bi bi-calendar-event me-1"></i>${UI.fmtDateTime ? UI.fmtDateTime(e.start_time) : UI.fmtDate(e.start_time)} · ${e.duration_minutes || "—"} min · ${e.total_questions} Q · ${e.total_marks} marks</div>
        <div class="row g-2 text-center mb-3"><div class="col-4"><div class="mini-stat"><b>${e.attempts}/${d.stats.students}</b><span>Attempted</span></div></div>
          <div class="col-4"><div class="mini-stat"><b>${pct(e.avg_percent)}</b><span>Average</span></div></div><div class="col-4"><div class="mini-stat"><b>${pct(e.pass_rate)}</b><span>Passed</span></div></div></div>
        ${e.topper ? `<div class="topper"><i class="bi bi-trophy-fill"></i><span>Topper: <b>${esc(e.topper.name)}</b> – ${e.topper.percentage}%</span></div>` : ""}
        <div class="d-flex gap-2 mt-3"><a class="btn btn-sm btn-primary flex-grow-1" href="results.html?exam=${e.id}"><i class="bi bi-trophy me-1"></i>Results</a><a class="btn btn-sm btn-light" href="exam-edit.html?id=${e.id}"><i class="bi bi-pencil"></i></a></div>
        </div></div>`).join("")}</div>` : UI.empty("No exams assigned to this batch yet.", "card-checklist");
    },
    assignments() {
      body.innerHTML = d.assignments.length ? `<div class="list-group list-group-flush">${d.assignments.map((a) => {
        const rate = d.stats.students ? Math.round((100 * a.submitted) / d.stats.students) : 0;
        return `<div class="list-group-item py-3"><div class="d-flex flex-wrap gap-3 align-items-center">
          <span class="ico-round"><i class="bi bi-${a.has_file ? "paperclip" : "journal-text"}"></i></span>
          <div class="flex-grow-1 min-w-0"><div class="fw-semibold">${esc(a.title)} ${statusChip(a.status)}</div>
            <div class="small text-secondary">${esc(a.assignment_type || "")} · due ${UI.fmtDate(a.deadline)} · max ${a.max_marks ?? "—"} marks${a.avg_marks != null ? ` · average ${a.avg_marks}` : ""}</div></div>
          <div style="min-width:220px"><div class="d-flex justify-content-between small mb-1"><span>${a.submitted}/${d.stats.students} submitted</span><span>${a.evaluated} graded</span></div>${bar(rate, rate >= 75 ? "good" : rate >= 40 ? "" : "low")}</div>
          <a class="btn btn-sm btn-light" href="assignments.html"><i class="bi bi-box-arrow-up-right"></i></a></div></div>`; }).join("")}</div>` : UI.empty("No assignments for this batch yet.", "journal-check");
    },
    faculty() {
      body.innerHTML = d.faculty.length ? `<div class="row g-3 p-3">${d.faculty.map((f) => `<div class="col-md-6 col-xl-4"><div class="person-tile"><span class="avatar avatar-lg">${esc(UI.initials(f.full_name))}</span>
        <div class="min-w-0"><div class="fw-bold">${esc(f.full_name)}</div><div class="small text-capitalize text-primary fw-semibold">${esc(f.role || "faculty")}</div>
        <div class="small text-secondary text-truncate"><i class="bi bi-envelope me-1"></i>${esc(f.email)}</div>${f.phone ? `<div class="small text-secondary"><i class="bi bi-telephone me-1"></i>${esc(f.phone)}</div>` : ""}
        <div class="small mt-1"><i class="bi bi-patch-question me-1"></i>${f.questions} questions written</div></div></div></div>`).join("")}</div>` : UI.empty("No faculty in this batch yet.", "person-badge");
    },
    activities() {
      body.innerHTML = d.activities.length ? `<div class="list-group list-group-flush">${d.activities.map((t) => {
        const rate = d.stats.students ? Math.round((100 * t.completed) / d.stats.students) : 0;
        return `<div class="list-group-item py-3 d-flex flex-wrap gap-3 align-items-center"><span class="ico-round alt"><i class="bi bi-lightning-charge"></i></span>
          <div class="flex-grow-1"><div class="fw-semibold">${esc(t.title)}</div><div class="small text-secondary text-capitalize">${esc((t.activity_type || "").replace("_", " "))} · ${t.points} points · ends ${UI.fmtDate(t.end_time)}</div></div>
          <div style="min-width:220px"><div class="small mb-1">${t.completed}/${d.stats.students} completed</div>${bar(rate, "good")}</div></div>`; }).join("")}</div>` : UI.empty("No activities yet.", "lightning-charge");
    },
    news() {
      body.innerHTML = d.announcements.length ? `<div class="list-group list-group-flush">${d.announcements.map((n) => `<div class="list-group-item py-3 d-flex gap-3 align-items-center">
        <span class="ico-round ${n.priority === "high" ? "hot" : ""}"><i class="bi bi-megaphone"></i></span><div class="flex-grow-1"><div class="fw-semibold">${esc(n.title)}</div>
        <div class="small text-secondary">${UI.timeAgo(n.published_at)}${n.priority === "high" ? ' · <span class="text-danger fw-semibold">Important</span>' : ""}</div></div></div>`).join("")}</div>
        <div class="p-3"><a class="btn btn-sm btn-light" href="announcements.html">All announcements</a></div>` : UI.empty("No announcements yet.", "megaphone");
    },
  };
  document.querySelectorAll("#bt [data-tab]").forEach((t) => (t.onclick = () => { document.querySelectorAll("#bt [data-tab]").forEach((x) => x.classList.toggle("active", x === t)); tabs[t.dataset.tab](); }));
  tabs.students();
  const openTab = (t) => { document.querySelector(`#bt [data-tab="${t}"]`)?.click(); document.getElementById("bt").scrollIntoView({ behavior: "smooth", block: "start" }); };
  document.querySelectorAll("[data-go]").forEach((k) => (k.onclick = () => ({ k1: () => openTab("students"), k2: () => openTab("exams"), k3: () => openTab("exams"), k4: () => openTab("assignments"),
    k5: () => openTab("exams"), k6: () => (location.href = `students.html?batch_id=${b.id}&fee_status=pending`) })[k.dataset.go]()));

  // ---------- export this batch ----------
  document.getElementById("xBatch").onclick = () => UI.run(() => Exporter.workbook(`Batch – ${b.name}`, [
    { name: "Students", columns: ["Roll no.", "Name", "Email", "Phone", "Exams", "Average %", "Best rank", "Submissions", "Engagement", "Fees"],
      rows: d.students.map((s) => [s.roll_number, s.full_name, s.email, s.phone, s.exams_taken, s.avg_percent, s.best_rank, s.submissions, s.engagement?.level, s.fee_status]) },
    { name: "Exams", columns: ["Exam", "Status", "Starts", "Questions", "Marks", "Attempted", "Average %", "Pass %", "Topper"],
      rows: d.exams.map((e) => [e.title, e.status, UI.fmtDate(e.start_time), e.total_questions, e.total_marks, e.attempts, e.avg_percent, e.pass_rate, e.topper ? `${e.topper.name} (${e.topper.percentage}%)` : ""]) },
    { name: "Assignments", columns: ["Assignment", "Type", "Deadline", "Max marks", "Submitted", "Graded", "Average marks"],
      rows: d.assignments.map((a) => [a.title, a.assignment_type, UI.fmtDate(a.deadline), a.max_marks, a.submitted, a.evaluated, a.avg_marks]) },
    { name: "Faculty", columns: ["Name", "Role", "Email", "Phone"], rows: d.faculty.map((f) => [f.full_name, f.role, f.email, f.phone]) },
  ]), { loading: "Preparing Excel…", success: "Downloaded." });
});
