/* Engagement monitoring – who is active, who is slipping, with charts, filters and reminders */
App.init({ roles: App.STAFF }).then(async () => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  let bucket = UI.qs("level") || UI.qs("bucket") || "all", batch = UI.qs("batch") || "", search = "", rows = [];
  const LV = ["Highly engaged", "Engaged", "At risk", "Inactive"], LVC = ["#10B981", "#0EA5E9", "#F59E0B", "#F43F5E"];
  const lvCls = { "Highly engaged": "lv-high", Engaged: "lv-ok", "At risk": "lv-risk", Inactive: "lv-off" };
  el.innerHTML = `<div class="page-head"><div><h1 class="page-title"><i class="bi bi-activity"></i>Engagement monitoring</h1>
      <div class="text-secondary small">Engagement score from logins, exams, submissions and activities · students are flagged after 3, 7, 15 and 30 days without activity</div></div>
      <div class="ms-auto d-flex gap-2 flex-wrap"><a class="btn btn-outline-light" href="reports.html"><i class="bi bi-file-earmark-bar-graph me-1"></i>Report</a></div></div>
    <div class="row g-3 mb-3" id="sum"></div>
    <div class="row g-3 mb-3">
      <div class="col-lg-4"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-pie-chart-fill me-2"></i>Engagement levels</div><div class="card-body"><div class="chart-box" id="cLv"></div></div></div></div>
      <div class="col-lg-4"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-hourglass-split me-2"></i>Days without activity</div><div class="card-body"><div class="chart-box" id="cDays"></div></div></div></div>
      <div class="col-lg-4"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-collection me-2"></i>Average score by batch</div><div class="card-body"><div class="chart-box" id="cBatch"></div></div></div></div>
    </div>
    <div class="card">
      <div class="toolbar-bar">
        <div class="search-box"><i class="bi bi-search"></i><input class="form-control" id="q" placeholder="Search by name, roll number or email" aria-label="Search students"></div>
        <div class="tb-filters"><label class="tb-select"><span>Batch</span><select class="form-select" id="batchSel"><option value="">All</option></select></label></div>
        <div class="seg" id="seg">${[["all", "All"], ["Highly engaged", "Highly engaged"], ["Engaged", "Engaged"], ["At risk", "At risk"], ["Inactive", "Inactive"], ["pending", "Pending work"]]
          .map(([k, l]) => `<button data-b="${k}">${l}</button>`).join("")}</div>
        <button class="btn btn-primary ms-auto" id="remind"><i class="bi bi-bell me-1"></i>Remind selected</button>
      </div>
      <div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead><tr><th><input type="checkbox" class="form-check-input" id="all" aria-label="Select all"></th><th>Student</th><th>Batch</th>
        <th style="min-width:170px">Engagement score</th><th>Level</th><th>Last active</th><th class="text-end">Pending</th><th></th></tr></thead><tbody id="tb" class="fade-rows"></tbody></table></div>
      <div class="card-footer small text-secondary" id="foot"></div></div>`;
  App.lookup("batches").then((b) => { const s = document.getElementById("batchSel"); s.innerHTML += b.map((x) => `<option value="${x.id}">${esc(x.name)}</option>`).join(""); s.value = batch; s.closest(".tb-select").classList.toggle("on", !!batch); }).catch(() => {});

  const kpi = (k, i, l, v, sub, key) => `<div class="col-6 col-md-4 col-xl-2"><a href="#" class="text-reset text-decoration-none" data-b="${key}"><div class="kpi ${k} ${bucket === key ? "kpi-on" : ""}"><div class="kpi-icon"><i class="bi bi-${i}"></i></div>
    <div class="kpi-val">${esc(v ?? 0)}</div><div class="kpi-lbl">${l}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ""}</div></a></div>`;

  function table() {
    const q = search.toLowerCase();
    const list = rows.filter((x) => !q || `${x.full_name} ${x.roll_number || ""} ${x.email}`.toLowerCase().includes(q));
    document.getElementById("tb").innerHTML = list.length ? list.map((x) => `<tr>
      <td><input type="checkbox" class="form-check-input" data-id="${x.user_id}" aria-label="Select ${esc(x.full_name)}"></td>
      <td><a class="d-flex align-items-center gap-2 text-reset text-decoration-none" href="students.html?id=${x.user_id}"><span class="avatar">${esc(UI.initials(x.full_name))}</span>
        <div class="min-w-0"><div class="fw-semibold">${esc(x.full_name)}</div><div class="small text-secondary">${esc(x.roll_number || x.email)}</div></div></a></td>
      <td class="small">${esc(x.batch || "—")}</td>
      <td><div class="d-flex align-items-center gap-2"><b style="width:28px">${x.score ?? 0}</b><div class="progress-slim ${x.score >= 60 ? "good" : x.score < 35 ? "low" : ""}"><span style="width:${x.score || 0}%"></span></div></div>
        <div class="small text-secondary mt-1">${x.logins ?? 0} logins · ${x.exams ?? 0} exams · ${x.subs ?? 0} submissions</div></td>
      <td><span class="lv ${lvCls[x.level] || ""}">${esc(x.level || "—")}</span></td>
      <td class="small">${x.last_at ? UI.timeAgo(x.last_at) : '<span class="text-secondary">Never</span>'}${x.days >= 3 && x.days < 999 ? `<div><span class="chip ${x.days >= 15 ? "chip-closed" : "chip-scheduled"}">${x.days} days</span></div>` : ""}</td>
      <td class="text-end">${x.pending ? `<span class="chip chip-scheduled">${x.pending}</span>` : "0"}</td>
      <td class="text-end"><a class="btn btn-sm btn-light" href="insights.html?user=${x.user_id}" title="Strengths, weaknesses & study plan"><i class="bi bi-graph-up-arrow"></i></a></td></tr>`).join("")
      : `<tr><td colspan="8">${UI.empty(rows.length ? "No students match your search." : bucket === "all" ? "No students yet – add students and assign them to a batch." : "No students in this group. 🎉", "emoji-smile")}</td></tr>`;
    document.getElementById("foot").textContent = `${list.length} student(s) shown`;
  }

  async function load() {
    document.querySelectorAll("#seg button").forEach((b) => b.classList.toggle("on", b.dataset.b === bucket));
    document.getElementById("tb").innerHTML = `<tr><td colspan="8"><div class="skeleton my-2"></div><div class="skeleton my-2" style="width:70%"></div></td></tr>`;
    let r;
    try { r = await API.call("engagement.overview", { bucket, batch_id: batch || null }); }
    catch (e) { document.getElementById("tb").innerHTML = `<tr><td colspan="8">${UI.empty(e.message, "exclamation-circle")}</td></tr>`; return; }
    rows = r.rows; const s = r.summary || {};
    document.getElementById("sum").innerHTML = [
      kpi("k1", "people-fill", "Students", s.total, `average score ${s.avg_score ?? 0}`, "all"), kpi("k3", "rocket-takeoff", "Highly engaged", s.high, "score 75+", "Highly engaged"),
      kpi("k2", "emoji-smile", "Engaged", s.engaged, "score 50–74", "Engaged"), kpi("k4", "exclamation-triangle", "At risk", s.risk, "score 25–49", "At risk"),
      kpi("k6", "moon-stars", "Inactive", s.inactive, "score below 25", "Inactive"), kpi("k5", "inbox", "Pending work", s.pending, "exams / assignments due", "pending")].join("");
    document.querySelectorAll("#sum [data-b]").forEach((c) => (c.onclick = (e) => { e.preventDefault(); bucket = c.dataset.b; load(); }));
    Charts.draw("#cLv", { type: "doughnut", labels: LV, keepLabels: true, series: [{ label: "Students", data: [s.high, s.engaged, s.risk, s.inactive], colors: LVC }], empty: "No students yet" });
    Charts.draw("#cDays", { type: "bar", keepLabels: true, labels: ["Active", "3+ days", "7+ days", "15+ days", "30+ days"], series: [{ label: "Students", data: [s.active, s.d3, s.d7, s.d15, s.d30], colors: ["#10B981", "#0EA5E9", "#F59E0B", "#F97316", "#F43F5E"] }], empty: "No students yet" });
    Charts.draw("#cBatch", { type: "bar", horizontal: true, labels: (r.by_batch || []).map((x) => String(x.batch).replace(/ 20\d\d – Batch /, " · ").replace(/ – /, " · ")), keepLabels: true, series: [{ label: "Average score", data: (r.by_batch || []).map((x) => x.avg_score), color: "#F97316" }], empty: "No batches yet" });
    table();
  }
  document.querySelectorAll("#seg button").forEach((b) => (b.onclick = () => { bucket = b.dataset.b; load(); }));
  document.getElementById("batchSel").onchange = (e) => { batch = e.target.value; e.target.closest(".tb-select").classList.toggle("on", !!batch); load(); };
  document.getElementById("q").addEventListener("input", UI.debounce((e) => { search = e.target.value.trim(); table(); }, 150));
  document.getElementById("all").onchange = (e) => document.querySelectorAll("[data-id]").forEach((c) => (c.checked = e.target.checked));
  document.getElementById("remind").onclick = async () => {
    const ids = [...document.querySelectorAll("[data-id]:checked")].map((c) => c.dataset.id);
    if (!ids.length) return UI.warn("Please tick the students you want to remind.");
    await UI.formModal({
      title: `Send reminder to ${ids.length} student(s)`, size: "", submitText: "Send",
      fields: [{ name: "title", label: "Title", required: true, col: "col-12", default: "We miss you!" },
        { name: "body", label: "Message", type: "textarea", rows: 3, required: true, col: "col-12", default: "You have pending work. Sign in and continue your preparation today." }],
      onSubmit: async (v) => { const r = await API.call("engagement.remind", { user_ids: ids, ...v }); UI.success(r.message); },
    });
  };
  load();
});
