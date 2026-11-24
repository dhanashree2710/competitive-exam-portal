/* Student preparation intelligence: strengths, weaknesses, engagement & a 7-day study plan */
App.init().then(async (user) => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  let uid = UI.qs("user");
  if (user.role !== "student" && !uid) {
    el.innerHTML = `<div class="page-head"><div><h1 class="page-title"><i class="bi bi-graph-up-arrow"></i>Student insights</h1>
        <div class="text-secondary small">Pick a student to see strengths, weak topics, subject performance, score trend and a 7-day study plan</div></div></div>
      <div class="card"><div class="toolbar-bar">
        <div class="search-box"><i class="bi bi-search"></i><input class="form-control" id="sf" placeholder="Search name, roll number or email" aria-label="Search students"></div>
        <div class="tb-filters"><label class="tb-select"><span>Batch</span><select class="form-select" id="sb"><option value="">All</option></select></label>
          <label class="tb-select"><span>Sort</span><select class="form-select" id="so"><option value="roll">Roll number</option><option value="low">Lowest score first</option><option value="high">Highest score first</option></select></label></div>
        <div class="tb-count" id="sc"></div></div>
        <div class="p-3"><div class="row g-3" id="sl"><div class="col-12 text-center py-4"><div class="loader-ring mx-auto"></div></div></div></div></div>`;
    App.lookup("batches").then((b) => (document.getElementById("sb").innerHTML += b.map((x) => `<option value="${x.id}">${esc(x.name)}</option>`).join(""))).catch(() => {});
    let list = [];
    const draw = () => {
      const q = document.getElementById("sf").value.toLowerCase(), so = document.getElementById("so").value;
      let l = list.filter((s) => !q || `${s.full_name} ${s.email} ${s.roll_number || ""}`.toLowerCase().includes(q));
      if (so !== "roll") l = [...l].sort((a, b) => (so === "low" ? 1 : -1) * ((a.avg_percent ?? -1) - (b.avg_percent ?? -1)));
      document.getElementById("sc").innerHTML = `<b>${l.length}</b> students`;
      document.getElementById("sl").innerHTML = l.length ? l.map((s) => `<div class="col-sm-6 col-lg-4 col-xxl-3"><a class="pick-card" href="insights.html?user=${s.id}">
          <span class="avatar avatar-lg">${s.avatar_url ? `<img src="${esc(s.avatar_url)}" alt="">` : esc(UI.initials(s.full_name))}</span>
          <span class="min-w-0 flex-grow-1"><b class="text-truncate d-block">${esc(s.full_name)}</b><small class="d-block text-truncate">${esc(s.roll_number || s.email)}</small>
            <small class="d-block text-truncate">${esc(s.batch?.name || "No batch")}</small></span>
          <span class="pick-score ${s.avg_percent >= 70 ? "good" : s.avg_percent >= 40 ? "" : s.avg_percent != null ? "low" : "none"}">${s.avg_percent != null ? Math.round(s.avg_percent) + "%" : "—"}<small>${s.exams_taken} exam${s.exams_taken === 1 ? "" : "s"}</small></span></a></div>`).join("")
        : `<div class="col-12">${UI.empty("No students found.", "search")}</div>`;
    };
    const load = async () => {
      const b = document.getElementById("sb").value;
      try { list = (await API.call("student.list", { pageSize: 200, filters: b ? { batch_id: b } : {} })).rows; } catch (e) { document.getElementById("sl").innerHTML = `<div class="col-12">${UI.empty(e.message, "exclamation-circle")}</div>`; return; }
      draw();
    };
    document.getElementById("sf").addEventListener("input", UI.debounce(draw, 120));
    document.getElementById("so").onchange = draw;
    document.getElementById("sb").onchange = (e) => { e.target.closest(".tb-select").classList.toggle("on", !!e.target.value); load(); };
    load();
    return;
  }
  el.innerHTML = `<div class="text-center py-5"><span class="spinner-border text-primary"></span></div>`;
  let d;
  try { d = await API.call("insights.get", uid ? { user_id: uid } : {}); } catch (e) { el.innerHTML = `<div class="card">${UI.empty(e.message, "exclamation-circle")}</div>`; return; }
  const o = d.overall || {}; const eng = d.engagement || {};
  // most specific level that has data: topics → chapters → subjects
  const areas = d.topics.length ? d.topics : d.chapters.length ? d.chapters : d.subjects;
  const areaLabel = d.topics.length ? "topic" : d.chapters.length ? "chapter" : "subject";
  const withAcc = areas.filter((a) => a.accuracy !== null && a.accuracy !== undefined);
  const strengths = [...withAcc].filter((a) => a.accuracy >= 75).sort((a, b) => b.accuracy - a.accuracy).slice(0, 6);
  const weak = [...withAcc].filter((a) => a.accuracy < 60).sort((a, b) => a.accuracy - b.accuracy).slice(0, 6);
  const focus = (weak.length ? weak : [...withAcc].sort((a, b) => a.accuracy - b.accuracy)).slice(0, 5);
  const avgT = d.time?.avg_seconds_per_question;
  const meter = (pct) => `<div class="meter ${pct >= 75 ? "good" : pct < 50 ? "bad" : ""}"><span style="width:${Math.max(2, Math.min(100, pct || 0))}%"></span></div>`;
  const back = "";

  // rule-based 7-day plan (works without AI)
  const plan = focus.length ? Array.from({ length: 7 }, (_, i) => {
    if (i === 6) return { day: 7, focus: "Full mock test", tasks: ["Take a timed mock test covering all subjects", "Review every wrong answer and note why", "Update your formula / mistakes notebook"], minutes: 180 };
    const a = focus[i % focus.length];
    const slow = avgT && avgT > 90;
    return { day: i + 1, focus: a.name, minutes: 90, tasks: [`Revise the concepts of “${a.name}” from notes / textbook (30 min)`,
      `Practise ${a.accuracy < 40 ? 15 : 20} questions on “${a.name}”, starting easy`, slow ? "Time yourself: aim for under 90 seconds per question" : `Re-attempt the questions you got wrong on “${a.name}”`] };
  }) : [];

  el.innerHTML = `<div class="page-head mb-3"><div>${back}<h1 class="page-title"><i class="bi bi-graph-up-arrow"></i>${user.role === "student" ? "My progress" : "Insights – " + esc(d.student.full_name)}</h1>
      <div class="text-secondary small">${esc(d.student.email)}${d.student.roll_number ? " · Roll " + esc(d.student.roll_number) : ""}</div></div>
      <div class="ms-auto d-flex gap-2 flex-wrap">${user.role === "student" ? "" : `<a class="btn btn-outline-light" href="insights.html"><i class="bi bi-people me-1"></i>All students</a><a class="btn btn-outline-light" href="students.html?id=${d.student.id}"><i class="bi bi-person-vcard me-1"></i>Full record</a>`}<button class="btn btn-primary" id="pdfBtn"><i class="bi bi-file-earmark-pdf me-1"></i>Download report</button></div></div>
    <div class="row g-3 mb-3">
      <div class="col-lg-3"><div class="card h-100"><div class="card-body text-center"><div class="small text-secondary mb-2">Engagement score</div>
        <div class="score-ring" style="--v:${eng.score || 0}"><div>${eng.score ?? 0}<div class="small text-secondary fw-normal" style="font-size:.8rem">/ 100</div></div></div>
        <div class="mt-2 fw-semibold">${esc(eng.level || "")}</div>
        <div class="small text-secondary">${eng.logins_14d ?? 0} logins (14 days) · ${eng.exams_30d ?? 0} exams · ${eng.submissions_30d ?? 0} submissions (30 days)${eng.pending ? ` · <span class="text-danger">${eng.pending} pending</span>` : ""}</div></div></div></div>
      <div class="col-lg-9"><div class="row g-3">
        ${[["Exams taken", o.exams ?? 0, "pencil-square"], ["Average score", o.exams ? UI.num(o.avg_pct, 1) + "%" : "—", "graph-up"], ["Best score", o.best_pct != null ? UI.num(o.best_pct, 1) + "%" : "—", "trophy"],
           ["Accuracy", o.exams ? UI.num(o.avg_accuracy, 1) + "%" : "—", "bullseye"], ["Best rank", o.best_rank ?? "—", "award"], ["Time / question", avgT ? UI.duration(avgT) : "—", "stopwatch"]]
          .map(([l, v, i]) => `<div class="col-6 col-md-4"><div class="card stat-card h-100"><div class="card-body d-flex gap-3 align-items-center"><div class="icon g1"><i class="bi bi-${i}"></i></div><div><div class="value">${v}</div><div class="small text-secondary">${l}</div></div></div></div></div>`).join("")}
      </div></div></div>
    ${!o.exams ? `<div class="card mb-3">${UI.empty(user.role === "student" ? "Take an exam (and wait for the result to be released) to see your strengths, weaknesses and study plan." : "No results yet for this student.", "bar-chart-line")}</div>` : `
    <div class="row g-3 mb-3">
      <div class="col-lg-6"><div class="card h-100"><div class="card-header"><i class="bi bi-hand-thumbs-up text-success me-1"></i>Strengths</div><div class="card-body">
        ${strengths.length ? strengths.map((a) => `<div class="mb-2"><div class="d-flex small"><span>${esc(a.name)}</span><b class="ms-auto">${UI.num(a.accuracy, 0)}%</b></div>${meter(a.accuracy)}</div>`).join("") : `<div class="text-secondary small">No ${areaLabel} above 75% accuracy yet – keep going!</div>`}</div></div></div>
      <div class="col-lg-6"><div class="card h-100"><div class="card-header"><i class="bi bi-exclamation-triangle text-danger me-1"></i>Needs work</div><div class="card-body">
        ${weak.length ? weak.map((a) => `<div class="mb-2"><div class="d-flex small"><span>${esc(a.name)}</span><b class="ms-auto">${UI.num(a.accuracy, 0)}%</b></div>${meter(a.accuracy)}<div class="small text-secondary">${a.correct} correct · ${a.wrong} wrong · ${a.skipped} skipped</div></div>`).join("") : `<div class="text-secondary small">Great – no ${areaLabel} below 60% accuracy.</div>`}</div></div></div>
    </div>
    <div class="row g-3 mb-3">
      <div class="col-lg-6"><div class="card h-100"><div class="card-header">Subject performance</div><div class="card-body">
        ${d.subjects.length ? d.subjects.map((a) => `<div class="mb-2"><div class="d-flex small"><span>${esc(a.name)}</span><span class="ms-auto">${UI.num(a.score)} / ${UI.num(a.max)} · <b>${a.score_pct != null ? UI.num(a.score_pct, 0) + "%" : "—"}</b></span></div>${meter(a.score_pct)}</div>`).join("") : '<div class="small text-secondary">Questions in your exams aren\'t linked to subjects yet.</div>'}</div></div></div>
      <div class="col-lg-6"><div class="card chart-card h-100"><div class="card-header"><i class="bi bi-graph-up-arrow me-2"></i>Score trend</div><div class="card-body"><div class="chart-box" id="iTrend"></div></div></div></div>
    </div>
    <div class="card mb-3"><div class="card-header d-flex align-items-center"><i class="bi bi-calendar-week me-2 text-primary"></i>7-day study plan
      <button class="btn btn-sm btn-primary ms-auto" id="aiPlan"><i class="bi bi-stars me-1"></i>Personalised AI plan</button></div>
      <div class="card-body"><div id="planBox">${renderPlan(plan, "Based on your weakest areas.")}</div></div></div>`}`;

  function renderPlan(p, note, tips = []) {
    if (!p.length) return UI.empty("Not enough data for a plan yet.", "calendar");
    return `<div class="small text-secondary mb-3">${esc(note)}</div><div class="row g-3">${p.map((x) => `<div class="col-md-6 col-xl-4"><div class="card plan-day h-100"><div class="card-body">
      <div class="d-flex"><b>Day ${esc(x.day)}</b><span class="ms-auto badge text-bg-light">${esc(x.minutes || 90)} min</span></div><div class="text-primary fw-semibold mb-1">${esc(x.focus)}</div>
      <ul class="small mb-0 ps-3">${(x.tasks || []).map((t) => `<li>${esc(t)}</li>`).join("")}</ul></div></div></div>`).join("")}</div>
      ${tips.length ? `<div class="alert alert-light border mt-3 small mb-0"><b>Tips:</b><ul class="mb-0">${tips.map((t) => `<li>${esc(t)}</li>`).join("")}</ul></div>` : ""}`;
  }
  document.getElementById("aiPlan")?.addEventListener("click", async () => {
    const r = await UI.run(() => API.call("ai.studyPlan", uid ? { user_id: uid } : {}), { loading: "AI is building a personalised plan…", success: false });
    if (r) { document.getElementById("planBox").innerHTML = renderPlan(r.plan, r.summary || "Personalised by AI from your results.", r.tips || []); UI.toast("Study plan ready."); }
  });
  if (document.getElementById("iTrend")) Charts.draw("#iTrend", { type: "line", percent: true, labels: d.trend.map((t) => t.title), series: [{ label: "Score", data: d.trend.map((t) => Number(t.pct) || 0), color: "#2563EB" }], empty: "No results yet" });
  document.getElementById("pdfBtn").addEventListener("click", () => {
    const rows = [...d.subjects.map((a) => ["Subject", a.name, a.correct, a.wrong, a.skipped, a.accuracy ?? "", a.score_pct ?? ""]),
      ...d.chapters.map((a) => ["Chapter", a.name, a.correct, a.wrong, a.skipped, a.accuracy ?? "", a.score_pct ?? ""]),
      ...d.topics.map((a) => ["Topic", a.name, a.correct, a.wrong, a.skipped, a.accuracy ?? "", a.score_pct ?? ""])];
    UI.run(() => Exporter.pdf(`Performance report – ${d.student.full_name}`, ["Level", "Area", "Correct", "Wrong", "Skipped", "Accuracy %", "Score %"], rows,
      { subtitle: `Exams: ${o.exams || 0} · Avg ${UI.num(o.avg_pct, 1)}% · Engagement ${eng.score ?? 0}/100 (${eng.level || ""})` }), { loading: "Creating PDF…", success: "Report downloaded." });
  });
});
