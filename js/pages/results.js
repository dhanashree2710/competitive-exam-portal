App.init().then(async (user) => {
  const el = document.getElementById("app");
  if (user.role === "student") {
    el.innerHTML = `<h1 class="page-title mb-3"><i class="bi bi-bar-chart-line me-2 text-primary"></i>My results</h1><div id="list"><div class="text-center py-5"><div class="loader-ring mx-auto"></div></div></div>`;
    let r;
    try { r = await API.call("student.results"); } catch (e) { document.getElementById("list").innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    document.getElementById("list").innerHTML = (r.pending ? `<div class="alert alert-info small"><i class="bi bi-hourglass-split me-1"></i>${r.pending} result(s) will appear here once your teacher releases them.</div>` : "") +
      (r.rows.length ? `<div class="row g-3">${r.rows.map((x) => { const pass = Number(x.percentage) >= Number(x.exam?.pass_percentage ?? 33); return `
        <div class="col-md-6 col-xl-4"><div class="card h-100"><div class="card-body">
          <div class="d-flex align-items-start mb-2"><h5 class="mb-0 flex-grow-1">${UI.esc(x.exam?.title)}</h5><span class="badge text-bg-${pass ? "success" : "danger"}">${pass ? "Pass" : "Fail"}</span></div>
          <div class="display-6 fw-bold ${pass ? "text-success" : "text-danger"}">${UI.num(x.percentage, 1)}%</div>
          <div class="text-secondary small mb-3">${UI.num(x.total_score)} / ${UI.num(x.max_score)} marks · Rank ${x.rank ?? "—"} · Accuracy ${UI.num(x.accuracy, 1)}%</div>
          <a class="btn btn-outline-primary btn-sm" href="result-view.html?id=${x.id}"><i class="bi bi-eye me-1"></i>View answers</a>
          <span class="small text-secondary ms-2">${UI.fmtDate(x.created_at)}</span>
        </div></div></div>`; }).join("")}</div>` : `<div class="card">${UI.empty("No results yet. Results appear after you finish an exam and your teacher releases them.", "bar-chart-line")}</div>`);
    return;
  }
  el.innerHTML = `<div class="d-flex flex-wrap gap-2 align-items-center mb-3"><h1 class="page-title"><i class="bi bi-bar-chart-line me-2 text-primary"></i>Results</h1>
    <select class="form-select ms-md-auto" style="max-width:420px" id="examSel"><option value="">Loading exams…</option></select></div><div id="box"></div>`;
  const sel = document.getElementById("examSel");
  try {
    const r = await API.call("crud.list", { table: "exams", pageSize: 200, filters: { status: ["live", "completed", "scheduled", "archived"] } });
    sel.innerHTML = `<option value="">— Choose an exam —</option>` + r.rows.map((e) => `<option value="${e.id}">${UI.esc(e.title)} (${e.status})${App.is("super_admin", "college_admin") && e.organization ? " · " + UI.esc(e.organization.name) : ""}</option>`).join("");
    const pre = UI.qs("exam");
    // open with an exam already shown: the one in the link, else the latest completed one
    const done = r.rows.filter((e) => e.status === "completed").sort((a, b) => String(b.end_time || "").localeCompare(String(a.end_time || "")));
    sel.value = pre || (done[0] || r.rows[0] || {}).id || "";
    if (!r.rows.length) document.getElementById("box").innerHTML = `<div class="card">${UI.empty("No published exams yet.", "bar-chart-line")}</div>`;
  } catch (e) { UI.handle(e); }
  const show = () => { if (sel.value) { history.replaceState(null, "", `?exam=${sel.value}`); ExamResults.render(document.getElementById("box"), sel.value); } };
  sel.addEventListener("change", show);
  show();
});
