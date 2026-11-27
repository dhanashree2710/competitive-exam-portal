App.init().then(async (user) => {
  const el = document.getElementById("app");
  const hour = new Date().getHours();
  const greet = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
  const isStudent = user.role === "student";
  el.innerHTML = `
    <div class="card hero-card mb-4"><div class="blob"></div><i class="bi bi-${isStudent ? "rocket-takeoff" : "mortarboard"} hero-icon"></i>
      <div class="card-body p-4 position-relative">
        <div class="small text-uppercase fw-semibold opacity-75 mb-1">${new Date().toLocaleDateString("en-IN", { weekday: "long", day: "numeric", month: "long" })}</div>
        <h1 class="h3 fw-bold mb-1">${greet}, ${UI.esc(user.full_name.split(" ")[0])}! 👋</h1>
        <div class="opacity-75">${UI.esc(UI.roleLabel(user.role))}${user.organization ? " · " + UI.esc(user.organization.name) : ""}</div>
        <div class="d-flex flex-wrap gap-2 mt-3">${isStudent
          ? `<a href="my-exams.html" class="btn btn-light btn-sm"><i class="bi bi-pencil-square me-1"></i>My exams</a><a href="my-assignments.html" class="btn btn-outline-light btn-sm"><i class="bi bi-journal-text me-1"></i>Assignments</a>`
          : `<a href="exam-wizard.html" class="btn btn-light btn-sm"><i class="bi bi-magic me-1"></i>Create exam</a><a href="reports.html" class="btn btn-outline-light btn-sm"><i class="bi bi-file-earmark-bar-graph me-1"></i>Reports</a><a href="questions.html" class="btn btn-outline-light btn-sm"><i class="bi bi-stars me-1"></i>AI questions</a><a href="engagement.html" class="btn btn-outline-light btn-sm"><i class="bi bi-activity me-1"></i>Engagement</a>`}</div>
      </div></div>
    <div id="flow" class="mb-4"></div>
    <div class="row g-3 mb-4 stagger" id="stats">${Array(4).fill('<div class="col-6 col-xl-3"><div class="card"><div class="card-body"><div class="skeleton mb-2" style="width:40%;height:26px"></div><div class="skeleton" style="width:70%"></div></div></div></div>').join("")}</div>
    <div id="orgGlance"></div>
    <div class="row g-3"><div class="col-lg-7 d-flex flex-column gap-3" id="left"></div><div class="col-lg-5 d-flex flex-column gap-3" id="right"></div></div>`;
  let d;
  try { d = await API.call("dashboard"); } catch (e) { document.getElementById("stats").innerHTML = `<div class="col-12">${UI.empty(e.message, "exclamation-circle")}</div>`; return; }

  const K = { g1: "k1", g2: "k5", g3: "k2", g4: "k4", g5: "k5", g6: "k1", g7: "k6", g8: "k3", g9: "k2" };
  const card = (label, value, icon, g, href, suffix = "") => `<div class="col-6 col-md-4 col-xl-3"><a href="${href || "#"}" class="text-decoration-none text-reset">
    <div class="kpi ${K[g] || "k1"}"><div class="kpi-icon"><i class="bi bi-${icon}"></i></div>
    <div class="kpi-val" data-count="${value ?? 0}" data-suffix="${suffix}">${value === null || value === undefined ? "—" : 0}</div><div class="kpi-lbl">${label}</div></div></a></div>`;
  const s = d.stats;
  const admin = App.isAdmin();
  const stats = isStudent
    ? [card("Exams available", s.available_exams, "pencil-square", "g3", "my-exams.html"), card("Upcoming exams", s.upcoming_exams, "calendar-event", "g2", "my-exams.html"),
       card("Results", s.results, "bar-chart-line", "g1", "results.html"), card("Average score", s.avg_percentage, "graph-up-arrow", "g5", "insights.html", "%"),
       card("Pending assignments", s.pending_assignments, "journal-text", "g4", "my-assignments.html"), card("Activity points", s.points, "lightning-charge", "g9", "activities.html")]
    : [...(App.is("super_admin", "college_admin") ? [card("Organizations", s.organizations, "building", "g6", "organizations.html")] : []),
       card("Students", s.students, "people", "g1", "students.html"),
       card("Faculty", s.faculty, "person-badge", "g5", admin ? "users.html?role=faculty" : "batches.html"),
       card("Batches", s.batches, "collection", "g2", "batches.html"), card("Questions", s.questions, "patch-question", "g4", "questions.html"),
       card("Exams", s.exams, "pencil-square", "g3", "exams.html"), card("Live now", s.live_exams, "broadcast", "g7", "exams.html?status=live"),
       card("To review", s.pending_reviews, "inbox", "g9", "assignments.html?status=published"), card("Inactive students", s.inactive_students, "person-exclamation", "g8", "engagement.html?level=Inactive")];
  document.getElementById("stats").innerHTML = stats.join("");
  flow(s);
  // animated counters
  document.querySelectorAll("[data-count]").forEach((n) => {
    const target = Number(n.dataset.count); if (!isFinite(target) || n.textContent === "—") return;
    const t0 = performance.now(), dur = 900;
    const step = (t) => { const k = Math.min(1, (t - t0) / dur); const v = target * (1 - Math.pow(1 - k, 3)); n.textContent = (Number.isInteger(target) ? Math.round(v) : v.toFixed(1)) + n.dataset.suffix; if (k < 1) requestAnimationFrame(step); };
    requestAnimationFrame(step);
  });

  const charts = [];
  const chart = (rows, title, suffix = "") => {
    const id = "dc" + charts.length; charts.push([id, rows, suffix]);
    return `<div class="card chart-card"><div class="card-header"><i class="bi bi-${suffix ? "graph-up-arrow" : "bar-chart-fill"} me-2"></i>${title}</div><div class="card-body"><div class="chart-box" id="${id}"></div></div></div>`;
  };
  const drawCharts = () => charts.forEach(([id, rows, suffix]) => Charts.draw("#" + id, suffix
    ? { type: "line", percent: true, labels: rows.map((r) => r.label), series: [{ label: "Score", data: rows.map((r) => r.value), color: "#2563EB" }], empty: "No results yet" }
    : { type: "bar", rainbow: true, labels: rows.map((r) => r.label), series: [{ label: "Submissions", data: rows.map((r) => r.value) }], empty: "No submissions this week" }));
  const left = document.getElementById("left");
  if (isStudent) {
    left.innerHTML = `<div class="card"><div class="card-header d-flex">My exams<a class="ms-auto small" href="my-exams.html">View all</a></div>
      <div class="list-group list-group-flush">${d.exams.length ? d.exams.map((e) => `<a class="list-group-item list-group-item-action d-flex align-items-center gap-3 py-3" href="my-exams.html">
        <span class="avatar g1"><i class="bi bi-pencil"></i></span><div class="flex-grow-1"><div class="fw-semibold">${UI.esc(e.title)}</div><div class="small text-secondary">${e.duration_minutes} min · ${e.total_questions} questions${e.start_time ? " · " + UI.fmtDateTime(e.start_time) : ""}</div></div>${UI.badge(e.state)}</a>`).join("") : UI.empty("No exams right now.", "pencil-square")}</div></div>
      ${chart(d.trend || [], "My score trend", "%")}`;
  } else {
    left.innerHTML = `${chart(d.trend || [], "Exam submissions – last 7 days")}
      <div class="card"><div class="card-header d-flex">Recent exams<a class="ms-auto small" href="exams.html">View all</a></div>
      <div class="list-group list-group-flush">${d.exams.length ? d.exams.map((e) => `<a class="list-group-item list-group-item-action d-flex align-items-center gap-3 py-3" href="exam-edit.html?id=${e.id}">
        <span class="avatar g2"><i class="bi bi-file-earmark-text"></i></span><div class="flex-grow-1"><div class="fw-semibold">${UI.esc(e.title)}</div><div class="small text-secondary">${UI.esc(e.organization?.name || "")} · ${e.total_questions || 0} questions${e.start_time ? " · " + UI.fmtDateTime(e.start_time) : ""}</div></div>${UI.badge(e.status)}</a>`).join("") : UI.empty("No exams yet. Create your first exam from the Exams page.", "pencil-square")}</div></div>`;
  }
  if (window.Charts) drawCharts();
  document.getElementById("right").innerHTML = `${isStudent ? `<div class="card"><div class="card-header d-flex">Pending assignments<a class="ms-auto small" href="my-assignments.html">View all</a></div>
      <div class="list-group list-group-flush">${d.assignments.length ? d.assignments.map((a) => `<a class="list-group-item list-group-item-action py-3" href="my-assignments.html"><div class="fw-semibold">${UI.esc(a.title)}</div><div class="small text-secondary"><i class="bi bi-clock me-1"></i>Due ${UI.fmtDateTime(a.deadline)}</div></a>`).join("") : `<div class="p-3 d-flex align-items-center gap-3"><span class="avatar g3"><i class="bi bi-check2-circle"></i></span><div class="flex-grow-1"><div class="fw-semibold">All assignments submitted</div><div class="small text-secondary">Your marks and feedback are on the Assignments page.</div></div><a class="btn btn-sm btn-outline-primary" href="my-assignments.html">View</a></div>`}</div></div>` : ""}
    <div class="card"><div class="card-header d-flex">Announcements<a class="ms-auto small" href="announcements.html">View all</a></div>
    <div class="list-group list-group-flush">${d.announcements.length ? d.announcements.map((a) => `<div class="list-group-item py-3"><div class="d-flex gap-2"><div class="fw-semibold flex-grow-1"><i class="bi bi-megaphone text-primary me-1"></i>${UI.esc(a.title)}</div>${a.priority && a.priority !== "normal" ? UI.badge(a.priority) : ""}</div>
      <div class="small clamp-2 mt-1">${UI.esc(a.body)}</div><div class="small text-secondary mt-1">${UI.timeAgo(a.published_at)}${a.author ? " · " + UI.esc(a.author.full_name) : ""}</div></div>`).join("") : UI.empty("No announcements.", "megaphone")}</div></div>`;

  // ---------- next exam countdown (students) ----------
  if (isStudent) {
    const next = (d.exams || []).filter((e) => e.start_time && new Date(e.start_time) > new Date()).sort((a, b) => new Date(a.start_time) - new Date(b.start_time))[0];
    const live = (d.exams || []).find((e) => ["open", "in_progress"].includes(e.state));
    const box = document.createElement("div"); box.className = "mt-3 small";
    document.querySelector(".hero-card .card-body").appendChild(box);
    if (live) box.innerHTML = `<i class="bi bi-broadcast text-warning me-1"></i><b>${UI.esc(live.title)}</b> is open now – <a class="link-light fw-bold" href="my-exams.html">start it</a>`;
    else if (next) {
      const tick = () => { const ms = new Date(next.start_time) - Date.now(); if (ms <= 0) { box.innerHTML = `<b>${UI.esc(next.title)}</b> is starting – <a class="link-light fw-bold" href="my-exams.html">open My exams</a>`; return; }
        const dd = Math.floor(ms / 864e5), h = Math.floor(ms / 36e5) % 24, mi = Math.floor(ms / 6e4) % 60, se = Math.floor(ms / 1e3) % 60;
        box.innerHTML = `<i class="bi bi-hourglass-split me-1"></i>Next exam <b>${UI.esc(next.title)}</b> starts in <span class="countdown">${dd ? dd + "d " : ""}${String(h).padStart(2, "0")}:${String(mi).padStart(2, "0")}:${String(se).padStart(2, "0")}</span>`; };
      tick(); setInterval(tick, 1000);
    }
  }
  // ---------- your administrator (faculty & students) ----------
  const admins = App.me?.org_admins || [];
  if (["faculty", "student"].includes(user.role)) {
    document.getElementById("right").insertAdjacentHTML("afterbegin", `<div class="card"><div class="card-header"><i class="bi bi-person-badge me-1 text-primary"></i>Your ${UI.esc(user.organization?.name || "organization")} admin</div>
      <div class="list-group list-group-flush">${admins.length ? admins.map((a) => `<div class="list-group-item d-flex gap-3 align-items-center"><span class="avatar g1">${UI.esc(UI.initials(a.full_name))}</span>
        <div><div class="fw-semibold">${UI.esc(a.full_name)}</div><div class="small text-secondary"><a href="mailto:${UI.esc(a.email)}">${UI.esc(a.email)}</a>${a.phone ? " · " + UI.esc(a.phone) : ""}</div></div></div>`).join("")
        : UI.empty("No admin has been set for your organization yet.", "person-badge")}</div></div>`);
  }
  // ---------- organizations & their admins (admins) ----------
  if (App.isAdmin()) {
    try {
      const ov = await API.call("org.overview");
      left.insertAdjacentHTML("beforeend", `<div class="card org-card"><div class="card-header d-flex">Organizations & admins${App.is("super_admin", "college_admin") ? '<a class="ms-auto small" href="organizations.html">Manage</a>' : ""}</div>
        <div class="list-group list-group-flush">${ov.rows.map((o) => `<div class="list-group-item py-3"><div class="d-flex align-items-center gap-2">
          <span class="avatar g${o.type === "root" ? 5 : o.type === "college" ? 1 : 2}"><i class="bi bi-${o.type === "root" ? "bank" : o.type === "college" ? "building" : "house-door"}"></i></span>
          <div class="flex-grow-1"><div class="fw-semibold">${UI.esc(o.name)} <span class="badge text-bg-light text-capitalize">${UI.esc(o.type)}</span> ${o.is_active === false ? '<span class="badge text-bg-secondary">Inactive</span>' : ""}</div>
          <div class="small text-secondary">${o.parent ? "Under " + UI.esc(o.parent.name) + " · " : ""}${o.students} students · ${o.faculty} faculty · ${o.exams} exams</div></div></div>
          <div class="mt-2">${o.admins.length ? o.admins.map((a) => `<span class="admin-chip" title="${UI.esc(a.email)}"><i class="bi bi-person-badge"></i>${UI.esc(a.full_name)}</span>`).join("") : '<span class="badge text-bg-warning">No admin yet</span>'}</div></div>`).join("") || UI.empty("No organizations.", "building")}</div></div>`);
    } catch (e) { /* older database: banner explains */ }
  }

  // super admin / college admin: every organization at a glance, with results and a one-click full download
  if (App.is("super_admin", "college_admin")) (async () => {
    let ov; try { ov = await API.call("export.org", { sheets: ["overview"] }); } catch { return; }
    const rows = (ov.sheets[0]?.rows || []).filter((r) => r[2] !== "Root");
    if (!rows.length) return;
    document.getElementById("orgGlance").innerHTML = `<div class="card mb-3"><div class="card-header d-flex align-items-center"><i class="bi bi-buildings me-2 text-primary"></i>Organizations at a glance
      ${App.is("super_admin") ? `<a class="ms-auto btn btn-sm btn-primary" href="data-export.html"><i class="bi bi-cloud-arrow-down me-1"></i>Download data</a>` : ""}</div>
      <div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead><tr><th>Organization</th><th class="text-end">Students</th><th class="text-end">Active (7 d)</th>
        <th class="text-end">Exams</th><th class="text-end">Results</th><th class="text-end">Average</th><th class="text-end">Pass rate</th><th class="text-end">Fees due</th></tr></thead><tbody>
      ${rows.map((r) => `<tr><td><div class="fw-semibold">${UI.esc(r[0])}</div><div class="small text-secondary">${UI.esc(r[2])} · ${UI.esc(r[1] || "")}${r[5] ? " · Admin: " + UI.esc(r[5]) : ""}</div></td>
        <td class="text-end">${r[7]}</td><td class="text-end">${r[8]}</td><td class="text-end">${r[10]}</td><td class="text-end">${r[12]}</td>
        <td class="text-end fw-semibold">${r[13] != null ? r[13] + "%" : "—"}</td><td class="text-end">${r[14] != null ? r[14] + "%" : "—"}</td>
        <td class="text-end">₹${Number(r[18] || 0).toLocaleString("en-IN")}</td></tr>`).join("")}</tbody></table></div></div>`;
  })();

  // ---------- "Your workflow": the role's steps in order, ticked when done, next one highlighted ----------
  function flow(s) {
    const n = (v) => Number(v) || 0;
    const F = {
      super_admin: ["Set up VidyaSetu", [
        ["organizations.html", "Organizations", "Add colleges & institutes with their admins", n(s.organizations) > 1],
        ["users.html", "People", "Admins, faculty and student logins", n(s.faculty) > 0],
        ["syllabus.html", "Syllabus", "Exam types, subjects, units, chapters", n(s.questions) > 0],
        ["exams.html", "Exams", "See every exam across organizations", n(s.exams) > 0],
        ["reports.html", "Reports", "Results & charts for each organization", false],
        ["data-export.html", "Data export", "Download full data per organization", false]]],
      college_admin: ["Run your college", [
        ["organizations.html", "Institutes", "Add partner institutes and their admins", n(s.organizations) > 1],
        ["users.html", "People", "Faculty and staff logins", n(s.faculty) > 0],
        ["syllabus.html", "Syllabus", "Subjects, units and chapters", n(s.questions) > 0],
        ["exams.html", "Exams", "Exams of the college and institutes", n(s.exams) > 0],
        ["reports.html", "Reports", "Results and engagement charts", false]]],
      institute_admin: ["Run your institute in 6 steps", [
        ["batches.html", "Batches", "Create batches (JEE, NEET…)", n(s.batches) > 0],
        ["students.html", "Students", "Add or import students with logins", n(s.students) > 0],
        ["questions.html", "Questions", "Build or import the question bank", n(s.questions) > 0],
        ["exam-wizard.html", "Create exam", "6-step wizard: pick questions, assign batches", n(s.exams) > 0],
        ["results.html", "Results", "Ranks, analysis and scorecards", n(s.exams) > n(s.live_exams)],
        ["engagement.html", "Engagement", "Follow up with inactive students", n(s.inactive_students) === 0 && n(s.students) > 0]]],
      faculty: ["Your teaching flow", [
        ["questions.html", "Questions", "Write, import or generate with AI", n(s.questions) > 0],
        ["exam-wizard.html", "Create exam", "Pick questions and assign batches", n(s.exams) > 0],
        ["assignments.html", "Assignment", "Upload a worksheet and publish", false],
        ["assignments.html?status=published", "Review work", "Grade submissions and give feedback", n(s.pending_reviews) === 0],
        ["results.html", "Results", "Ranks and topic-wise analysis", n(s.exams) > n(s.live_exams)],
        ["insights.html", "Insights", "Weak topics & study plans", false]]],
      student: ["Your exam journey", [
        ["my-exams.html", "Take exams", n(s.available_exams) ? `${n(s.available_exams)} open for you now` : "Live and upcoming exams", n(s.available_exams) === 0 && n(s.results) > 0],
        ["results.html", "Results", "Score, rank and solutions", n(s.results) > 0],
        ["my-assignments.html", "Assignments", n(s.pending_assignments) ? `${n(s.pending_assignments)} waiting for you` : "Submit work with files", n(s.pending_assignments) === 0],
        ["activities.html", "Practice", "Quizzes & challenges for points", n(s.points) > 0],
        ["insights.html", "Progress & plan", "Strengths, weak topics, 7-day plan", false]]],
    }[user.role];
    if (!F) return;
    const [title, steps] = F;
    const next = steps.findIndex((x) => !x[3]);
    const done = steps.filter((x) => x[3]).length;
    document.getElementById("flow").innerHTML = `<div class="flow"><div class="flow-head"><i class="bi bi-signpost-split-fill" style="color:#F97316;font-size:1.2rem"></i><h2>${UI.esc(title)}</h2>
      <span class="chip ${done === steps.length ? "chip-completed" : "chip-scheduled"}">${done}/${steps.length} done</span></div>
      <div class="flow-steps">${steps.map(([href, l, d, ok], i) => `<a class="flow-step ${ok ? "done" : i === next ? "next" : ""}" href="${href}">
        <span class="n">${ok ? '<i class="bi bi-check-lg"></i>' : i + 1}</span><b>${UI.esc(l)}</b><small>${UI.esc(d)}</small>
        <span class="go">${ok ? "Open" : i === next ? "Start here" : "Go"} <i class="bi bi-arrow-right"></i></span></a>`).join("")}</div></div>`;
  }
});
