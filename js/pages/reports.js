/* Reports & exports: CSV / Excel / PDF */
App.init().then(async (user) => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  const staff = App.isStaff();
  const TYPES = staff ? [
    ["exam_results", "Exam results & ranking", "trophy", "One exam: rank, marks, percentile, accuracy, time, tab switches"],
    ["student_performance", "Student performance summary", "people", "Every student: exams taken, average & best score, engagement"],
    ["assignment_marks", "Assignment marks", "journal-text", "One assignment: submissions, status, marks and feedback"],
    ["engagement", "Engagement & monitoring", "activity", "Score, level, inactivity days, logins, pending work"],
    ["question_bank", "Question bank", "patch-question", "All questions with type, level, syllabus and status"],
  ] : [["my_results", "My results", "bar-chart-line", "All your released exam results"]];
  el.innerHTML = `<div class="page-head mb-3"><div><h1 class="page-title"><i class="bi bi-file-earmark-bar-graph me-2 text-primary"></i>Reports & exports</h1>
      <div class="text-secondary small">Choose a report, preview it, then download as PDF, Excel or CSV.</div></div></div>
    <div class="row g-3 mb-3">${TYPES.map(([k, l, i, dsc], n) => `<div class="col-md-6 col-xl-4"><div class="card h-100 cursor-pointer ${n ? "" : "border-primary"}" data-type="${k}"><div class="card-body d-flex gap-3">
      <div class="icon g${(n % 6) + 1}" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;color:#fff"><i class="bi bi-${i}"></i></div>
      <div><div class="fw-semibold">${l}</div><div class="small text-secondary">${dsc}</div></div></div></div></div>`).join("")}</div>
    <div class="card"><div class="card-body"><div class="row g-2 align-items-end" id="params"></div></div></div>
    <div class="card mt-3 d-none" id="out"><div class="card-header d-flex flex-wrap gap-2 align-items-center"><span id="outTitle"></span>
      <div class="ms-auto d-flex gap-2"><button class="btn btn-sm btn-danger" data-x="pdf"><i class="bi bi-file-earmark-pdf me-1"></i>PDF</button>
      <button class="btn btn-sm btn-success" data-x="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Excel</button>
      <button class="btn btn-sm btn-secondary" data-x="csv"><i class="bi bi-filetype-csv me-1"></i>CSV</button></div></div>
      <div class="p-3 border-bottom report-visual"><div class="row g-3 mb-1" id="rKpi"></div><div class="row g-3" id="rCharts"></div></div>
      <div class="px-3 pt-3 pb-1 small fw-semibold text-uppercase text-secondary"><i class="bi bi-table me-1"></i>Data</div>
      <div class="table-responsive" style="max-height:60vh"><table class="table table-sm table-hover mb-0"><thead id="oh"></thead><tbody id="ob"></tbody></table></div>
      <div class="card-footer small text-secondary" id="of"></div></div>`;
  let type = TYPES[0][0]; let report = null;
  async function params() {
    const p = document.getElementById("params");
    let html = "";
    if (type === "exam_results") {
      const ex = await API.call("crud.list", { table: "exams", pageSize: 300, filters: { status: ["live", "completed", "scheduled", "archived"] } }).catch(() => ({ rows: [] }));
      html = `<div class="col-md-8"><label class="form-label">Exam</label><select class="form-select" data-p="exam_id"><option value="">— Choose an exam —</option>${ex.rows.sort((a, b) => (b.status === "completed") - (a.status === "completed")).map((e) => `<option value="${e.id}">${esc(e.title)} (${e.status})${App.is("super_admin", "college_admin") && e.organization ? " · " + esc(e.organization.name) : ""}</option>`).join("")}</select></div>`;
    } else if (type === "assignment_marks") {
      const a = await API.call("crud.list", { table: "assignments", pageSize: 300 }).catch(() => ({ rows: [] }));
      html = `<div class="col-md-8"><label class="form-label">Assignment</label><select class="form-select" data-p="assignment_id"><option value="">— Choose an assignment —</option>${a.rows.map((x) => `<option value="${x.id}">${esc(x.title)}</option>`).join("")}</select></div>`;
    } else if (["student_performance", "engagement"].includes(type)) {
      const b = await App.lookup("batches").catch(() => []);
      html = `<div class="col-md-8"><label class="form-label">Batch (optional)</label><select class="form-select" data-p="batch_id"><option value="">All students</option>${b.map((x) => `<option value="${x.id}">${esc(x.name)}</option>`).join("")}</select></div>`;
    } else html = `<div class="col-md-8 small text-secondary">No options needed.</div>`;
    p.innerHTML = html + `<div class="col-md-4"><button class="btn btn-primary w-100" id="gen"><i class="bi bi-play-fill me-1"></i>Generate report</button></div>`;
    document.getElementById("gen").onclick = () => generate();
    // pre-select the first exam / assignment and show a preview straight away
    const s = p.querySelector("select[data-p='exam_id'], select[data-p='assignment_id']");
    if (s && s.options.length > 1) s.selectedIndex = 1;
    generate(true);
  }
  async function generate(quiet) {
    const p = { type }; document.querySelectorAll("[data-p]").forEach((i) => { if (i.value) p[i.dataset.p] = i.value; });
    if (type === "exam_results" && !p.exam_id) return quiet ? null : UI.warn("Please choose an exam.");
    if (type === "assignment_marks" && !p.assignment_id) return quiet ? null : UI.warn("Please choose an assignment.");
    report = quiet ? await API.call("reports.get", p).catch(() => null)
                   : await UI.run(() => API.call("reports.get", p), { loading: "Building report…", success: false });
    if (!report) return;
    document.getElementById("out").classList.remove("d-none");
    document.getElementById("outTitle").innerHTML = `<b>${esc(report.title)}</b>`;
    document.getElementById("oh").innerHTML = `<tr>${report.columns.map((c) => `<th>${esc(c)}</th>`).join("")}</tr>`;
    document.getElementById("ob").innerHTML = report.rows.length ? report.rows.slice(0, 200).map((r) => `<tr>${r.map((v) => `<td class="small">${esc(v ?? "")}</td>`).join("")}</tr>`).join("") : `<tr><td colspan="${report.columns.length}">${UI.empty("No data for this report yet.", "inbox")}</td></tr>`;
    document.getElementById("of").textContent = `${report.rows.length} row(s)${report.rows.length > 200 ? " – preview shows the first 200; downloads include everything" : ""}`;
    visuals(report);
  }

  // ---------- charts for every report ----------
  function visuals(r) {
    const kpi = document.getElementById("rKpi"), box = document.getElementById("rCharts");
    const col = (name) => r.columns.indexOf(name);
    const num = (name) => r.rows.map((x) => Number(x[col(name)])).filter((v) => !isNaN(v) && v !== null);
    const avg = (a) => (a.length ? Math.round((a.reduce((x, y) => x + y, 0) / a.length) * 10) / 10 : null);
    const count = (name) => { const m = {}; r.rows.forEach((x) => { const k = x[col(name)] ?? "—"; m[k] = (m[k] || 0) + 1; }); return m; };
    const bands = (vals, edges = [0, 20, 40, 60, 80, 100]) => edges.slice(0, -1).map((lo, i) => vals.filter((v) => v >= lo && (v < edges[i + 1] || (i === edges.length - 2 && v <= edges[i + 1]))).length);
    const bandLabels = ["0–20%", "20–40%", "40–60%", "60–80%", "80–100%"];
    const bandColors = ["#F43F5E", "#F59E0B", "#0EA5E9", "#2563EB", "#10B981"];
    const top = (labelCol, valCol, n = 10, asc = false) => [...r.rows].filter((x) => x[col(valCol)] != null).sort((a, b) => (asc ? 1 : -1) * (Number(a[col(valCol)]) - Number(b[col(valCol)]))).slice(0, n);
    const tiles = (list) => (kpi.innerHTML = list.map(([i, l, v, k]) => `<div class="col-6 col-lg-3"><div class="kpi ${k}"><div class="kpi-icon"><i class="bi bi-${i}"></i></div><div class="kpi-val">${esc(v ?? "—")}</div><div class="kpi-lbl">${l}</div></div></div>`).join(""));
    const slots = (list) => { box.innerHTML = list.map(([t, i], n) => `<div class="col-md-6 ${list.length > 2 ? "col-xl-4" : ""}"><div class="chart-panel"><div class="cp-title"><i class="bi bi-${i} me-1"></i>${t}</div><div class="chart-box" id="rc${n}"></div></div></div>`).join(""); };
    kpi.innerHTML = box.innerHTML = "";
    if (!r.rows.length) return;
    const pctOf = (a, b) => (b ? Math.round((1000 * a) / b) / 10 : 0);

    if (r.columns[0] === "Rank") {                       // exam results
      const p = num("Percentage"), res = count("Result");
      tiles([["people", "Students", r.rows.length, "k1"], ["speedometer2", "Average", avg(p) + "%", "k2"], ["award", "Highest", Math.max(...p) + "%", "k3"], ["patch-check", "Pass rate", pctOf(res.Pass || 0, r.rows.length) + "%", "k4"]]);
      slots([["Score distribution", "bar-chart-fill"], ["Pass / fail", "pie-chart-fill"], ["Top 10 students", "trophy-fill"]]);
      Charts.draw("#rc0", { type: "bar", labels: bandLabels, series: [{ label: "Students", data: bands(p), colors: bandColors }] });
      Charts.draw("#rc1", { type: "doughnut", labels: ["Pass", "Fail"], series: [{ label: "Students", data: [res.Pass || 0, res.Fail || 0], colors: ["#10B981", "#F43F5E"] }], keepLabels: true });
      const t = top("Student", "Percentage"); Charts.draw("#rc2", { type: "bar", horizontal: true, percent: true, labels: t.map((x) => x[col("Student")]), series: [{ label: "Score", data: t.map((x) => Number(x[col("Percentage")])), color: "#2563EB" }] });
    } else if (col("Engagement level") >= 0) {            // student performance
      const a = num("Average %"), lv = count("Engagement level");
      tiles([["people", "Students", r.rows.length, "k1"], ["speedometer2", "Average score", avg(a) + "%", "k2"], ["award", "Best average", (a.length ? Math.max(...a) : "—") + "%", "k3"], ["activity", "Highly engaged", lv["Highly engaged"] || 0, "k4"]]);
      slots([["Average score bands", "bar-chart-fill"], ["Engagement mix", "pie-chart-fill"], ["Top 10 by average", "trophy-fill"]]);
      Charts.draw("#rc0", { type: "bar", labels: bandLabels, series: [{ label: "Students", data: bands(a), colors: bandColors }] });
      const L = ["Highly engaged", "Engaged", "At risk", "Inactive"]; Charts.draw("#rc1", { type: "doughnut", labels: L, series: [{ label: "Students", data: L.map((k) => lv[k] || 0), colors: ["#10B981", "#0EA5E9", "#F59E0B", "#F43F5E"] }], keepLabels: true });
      const t = top("Student", "Average %"); Charts.draw("#rc2", { type: "bar", horizontal: true, percent: true, labels: t.map((x) => x[col("Student")]), series: [{ label: "Average", data: t.map((x) => Number(x[col("Average %")])), color: "#F97316" }] });
    } else if (col("Feedback") >= 0) {                     // assignment marks
      const st = count("Status"), m = r.rows.filter((x) => x[col("Marks")] != null).map((x) => pctOf(Number(x[col("Marks")]), Number(x[col("Max marks")])));
      tiles([["inbox", "Submissions", r.rows.length, "k1"], ["check2-circle", "Graded", st.evaluated || 0, "k3"], ["hourglass-split", "Waiting", (st.submitted || 0) + (st.late || 0), "k4"], ["speedometer2", "Average marks", m.length ? avg(m) + "%" : "—", "k2"]]);
      slots([["Submission status", "pie-chart-fill"], ["Marks distribution", "bar-chart-fill"]]);
      const keys = Object.keys(st); Charts.draw("#rc0", { type: "doughnut", labels: keys.map((k) => k.replace("_", " ")), series: [{ label: "Submissions", data: keys.map((k) => st[k]) }], keepLabels: true });
      Charts.draw("#rc1", { type: "bar", labels: bandLabels, series: [{ label: "Students", data: bands(m), colors: bandColors }], empty: "Nothing graded yet" });
    } else if (col("Days inactive") >= 0) {                // engagement
      const lv = count("Level"), d = r.rows.map((x) => x[col("Days inactive")]);
      tiles([["people", "Students", r.rows.length, "k1"], ["emoji-smile", "Engaged", (lv["Highly engaged"] || 0) + (lv.Engaged || 0), "k3"], ["exclamation-triangle", "At risk", lv["At risk"] || 0, "k4"], ["moon", "Inactive", lv.Inactive || 0, "k6"]]);
      slots([["Engagement levels", "pie-chart-fill"], ["Days since last activity", "bar-chart-fill"], ["Needs attention (lowest scores)", "exclamation-diamond-fill"]]);
      const L = ["Highly engaged", "Engaged", "At risk", "Inactive"]; Charts.draw("#rc0", { type: "doughnut", labels: L, series: [{ label: "Students", data: L.map((k) => lv[k] || 0), colors: ["#10B981", "#0EA5E9", "#F59E0B", "#F43F5E"] }], keepLabels: true });
      const DL = ["Today", "1–3 days", "4–7 days", "8–14 days", "15+ days / never"];
      Charts.draw("#rc1", { type: "bar", labels: DL, keepLabels: true, series: [{ label: "Students", colors: ["#10B981", "#0EA5E9", "#2563EB", "#F59E0B", "#F43F5E"],
        data: [d.filter((v) => v === 0).length, d.filter((v) => v >= 1 && v <= 3).length, d.filter((v) => v >= 4 && v <= 7).length, d.filter((v) => v >= 8 && v <= 14).length, d.filter((v) => v == null || v >= 15).length] }] });
      const t = top("Student", "Score", 10, true); Charts.draw("#rc2", { type: "bar", horizontal: true, labels: t.map((x) => x[col("Student")]), series: [{ label: "Engagement score", data: t.map((x) => Number(x[col("Score")]) || 0.5), color: "#F43F5E" }] });
    } else if (col("Difficulty") >= 0) {                   // question bank
      const df = count("Difficulty"), sb = count("Subject"), ty = count("Type"), stt = count("Status");
      tiles([["patch-question", "Questions", r.rows.length, "k1"], ["emoji-smile", "Easy", df.easy || 0, "k3"], ["emoji-neutral", "Medium", df.medium || 0, "k4"], ["fire", "Hard", df.hard || 0, "k6"]]);
      slots([["By difficulty", "pie-chart-fill"], ["By subject", "bar-chart-fill"], ["By question type", "ui-checks"], ["Review status", "check2-square"]]);
      Charts.draw("#rc0", { type: "doughnut", labels: ["Easy", "Medium", "Hard"], series: [{ label: "Questions", data: [df.easy || 0, df.medium || 0, df.hard || 0], colors: ["#10B981", "#F59E0B", "#F43F5E"] }], keepLabels: true });
      const sk = Object.keys(sb).sort((a, b) => sb[b] - sb[a]); Charts.draw("#rc1", { type: "bar", rainbow: true, labels: sk, series: [{ label: "Questions", data: sk.map((k) => sb[k]) }] });
      const tk = Object.keys(ty); Charts.draw("#rc2", { type: "bar", rainbow: true, labels: tk.map((k) => k.replace(/_/g, " ")), series: [{ label: "Questions", data: tk.map((k) => ty[k]) }] });
      const stk = Object.keys(stt); Charts.draw("#rc3", { type: "doughnut", labels: stk.map((k) => k.replace("_", " ")), series: [{ label: "Questions", data: stk.map((k) => stt[k]) }], keepLabels: true });
    } else if (r.columns[0] === "Exam") {                  // my results (student)
      const p = num("Percentage"), ac = num("Accuracy"), rows = [...r.rows].reverse();
      tiles([["card-checklist", "Exams", r.rows.length, "k1"], ["speedometer2", "Average", avg(p) + "%", "k2"], ["award", "Best", Math.max(...p) + "%", "k3"], ["bullseye", "Accuracy", avg(ac) + "%", "k4"]]);
      slots([["Your score trend", "graph-up-arrow"], ["Accuracy by exam", "bullseye"]]);
      Charts.draw("#rc0", { type: "line", percent: true, labels: rows.map((x) => x[col("Exam")]), series: [{ label: "Score", data: rows.map((x) => Number(x[col("Percentage")])), color: "#2563EB" }] });
      Charts.draw("#rc1", { type: "bar", percent: true, rainbow: true, labels: rows.map((x) => x[col("Exam")]), series: [{ label: "Accuracy", data: rows.map((x) => Number(x[col("Accuracy")])) }] });
    }
  }
  document.querySelectorAll("[data-type]").forEach((c) => (c.onclick = () => {
    type = c.dataset.type; document.querySelectorAll("[data-type]").forEach((x) => x.classList.toggle("border-primary", x === c));
    document.getElementById("out").classList.add("d-none"); params();
  }));
  document.querySelectorAll("[data-x]").forEach((b) => (b.onclick = () => {
    if (!report) return;
    if (!report.rows.length) return UI.warn("This report has no rows to download.");
    const f = b.dataset.x;
    // the PDF also carries the charts shown on screen
    const pics = async () => (await Promise.all([...document.querySelectorAll("#rCharts .chart-panel")].map(async (p) => ({ title: p.querySelector(".cp-title")?.innerText.trim(), src: await Charts.toPng(p.querySelector(".chart-box")) })))).filter((x) => x.src);
    UI.run(async () => (f === "csv" ? Exporter.csv(report.title, report.columns, report.rows) : f === "pdf" ? Exporter.pdf(report.title, report.columns, report.rows, { images: await pics(), landscape: true }) : Exporter[f](report.title, report.columns, report.rows)), { loading: "Preparing download…", success: "Download ready." });
  }));
  params();
});
