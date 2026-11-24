/* Data export – download the full data of one organization (or all) as one Excel workbook, or sheet by sheet */
App.init({ roles: ["super_admin"] }).then(async (user) => {
  const el = document.getElementById("app");
  const esc = UI.esc;
  const SHEETS = [
    ["overview", "Overview", "building", "One row per organization: people, exams, scores, fees"],
    ["staff", "Staff", "person-badge", "Admins and faculty with contact details"],
    ["students", "Students", "mortarboard", "Full student records – personal, family, academic, fees"],
    ["batches", "Batches", "collection", "Batches with student count and faculty"],
    ["exams", "Exams", "card-checklist", "Every exam with attempts, average and pass rate"],
    ["results", "Results", "trophy", "Every student's score, rank and percentile"],
    ["assignments", "Assignments", "journal-check", "Assignments with submission counts and averages"],
    ["submissions", "Submissions", "inbox", "Every submission with status, marks and feedback"],
    ["engagement", "Engagement", "speedometer", "Engagement score, inactivity and pending work"],
  ];
  const all = user.role === "super_admin";
  el.innerHTML = `
    <div class="page-head mb-3"><div><h1 class="page-title"><i class="bi bi-cloud-arrow-down me-2 text-primary"></i>Data export</h1>
      <div class="text-secondary small">Download the complete data of ${all ? "any organization – or all of them –" : "your organization"} in one Excel file, or sheet by sheet.</div></div></div>
    <div class="row g-3 mb-3" id="orgCards"><div class="col-12 text-center py-4"><div class="loader-ring mx-auto"></div></div></div>
    <div class="card mb-3"><div class="card-body">
      <div class="row g-3 align-items-end">
        <div class="col-md-5"><label class="form-label fw-semibold">Organization</label><select class="form-select" id="org"></select></div>
        <div class="col-md-3"><div class="form-check form-switch mb-2"><input class="form-check-input" type="checkbox" id="kids" checked><label class="form-check-label" for="kids">Include partner institutes</label></div></div>
        <div class="col-md-4 d-flex gap-2 flex-wrap justify-content-md-end">
          <button class="btn btn-light" id="preview"><i class="bi bi-eye me-1"></i>Preview</button>
          <button class="btn btn-primary" id="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Download Excel</button></div>
      </div>
      <div class="mt-3"><div class="d-flex align-items-center mb-2"><span class="fw-semibold small text-uppercase text-secondary">Sheets to include</span>
        <button class="btn btn-link btn-sm ms-auto p-0" id="toggleAll">Select none</button></div>
        <div class="row g-2" id="sheetPick">${SHEETS.map(([k, l, i, d]) => `<div class="col-sm-6 col-lg-4"><label class="sheet-pick"><input type="checkbox" class="form-check-input" value="${k}" checked>
          <i class="bi bi-${i}"></i><span><b>${l}</b><small>${d}</small></span></label></div>`).join("")}</div></div>
    </div></div>
    <div class="card d-none" id="out"><div class="card-header d-flex flex-wrap gap-2 align-items-center"><span id="outTitle" class="fw-semibold"></span>
      <div class="ms-auto d-flex gap-2"><button class="btn btn-sm btn-outline-secondary" id="csv"><i class="bi bi-filetype-csv me-1"></i>This sheet (CSV)</button>
      <button class="btn btn-sm btn-outline-danger" id="pdf"><i class="bi bi-file-earmark-pdf me-1"></i>This sheet (PDF)</button></div></div>
      <div class="px-3 pt-2"><ul class="nav nav-tabs flex-nowrap overflow-auto" id="tabs"></ul></div>
      <div class="table-responsive" style="max-height:60vh"><table class="table table-sm table-hover mb-0"><thead id="oh"></thead><tbody id="ob"></tbody></table></div>
      <div class="card-footer small text-secondary" id="of"></div></div>`;

  // ---------- organization picker + summary cards ----------
  const orgs = await App.lookup("organizations").catch(() => []);
  const sel = document.getElementById("org");
  sel.innerHTML = (all ? `<option value="">All organizations</option>` : "") +
    orgs.filter((o) => o.type !== "root" || all).map((o) => `<option value="${o.id}">${esc(o.name)} (${esc(o.type)})</option>`).join("");
  if (!all && user.organization_id) sel.value = user.organization_id;
  const syncKids = () => { const o = orgs.find((x) => x.id === sel.value); document.getElementById("kids").closest(".col-md-3").classList.toggle("invisible", !(o && o.type !== "institute")); };
  sel.addEventListener("change", syncKids); syncKids();

  try {
    const ov = await API.call("export.org", { sheets: ["overview"] });
    const rows = ov.sheets[0]?.rows || [];
    document.getElementById("orgCards").innerHTML = rows.filter((r) => r[2] !== "Root" || r[7] > 0).map((r) => `<div class="col-md-6 col-xl-4"><div class="card h-100 org-export">
      <div class="card-body"><div class="d-flex align-items-start gap-2 mb-2"><span class="icon g${r[2] === "College" ? 1 : 3}"><i class="bi bi-${r[2] === "College" ? "buildings" : "building"}"></i></span>
        <div class="min-w-0"><div class="fw-bold text-truncate" title="${esc(r[0])}">${esc(r[0])}</div><div class="small text-secondary">${esc(r[2])} · ${esc(r[1] || "")}${r[4] ? " · " + esc(r[4]) : ""}</div></div></div>
        <div class="row g-2 text-center small mb-3">
          <div class="col-3"><div class="mini-stat"><b>${r[7]}</b><span>Students</span></div></div><div class="col-3"><div class="mini-stat"><b>${r[6]}</b><span>Faculty</span></div></div>
          <div class="col-3"><div class="mini-stat"><b>${r[10]}</b><span>Exams</span></div></div><div class="col-3"><div class="mini-stat"><b>${r[13] ?? "—"}${r[13] != null ? "%" : ""}</b><span>Avg</span></div></div></div>
        <div class="d-flex flex-wrap gap-2 small text-secondary mb-3"><span><i class="bi bi-trophy me-1"></i>${r[12]} results</span><span><i class="bi bi-journal-check me-1"></i>${r[16]} submissions</span>
          <span><i class="bi bi-currency-rupee"></i>${Number(r[18] || 0).toLocaleString("en-IN")} due</span></div>
        <button class="btn btn-sm btn-outline-primary w-100" data-quick="${esc(r[0])}"><i class="bi bi-download me-1"></i>Download all data</button></div></div></div>`).join("")
      || `<div class="col-12">${UI.empty("No organizations yet.", "building")}</div>`;
    document.querySelectorAll("[data-quick]").forEach((b) => (b.onclick = () => {
      const o = orgs.find((x) => x.name === b.dataset.quick); if (!o) return;
      sel.value = o.id; syncKids(); document.querySelectorAll("#sheetPick input").forEach((i) => (i.checked = true)); download();
    }));
  } catch (e) { document.getElementById("orgCards").innerHTML = `<div class="col-12">${UI.empty(e.message, "exclamation-circle")}</div>`; }

  // ---------- sheets ----------
  const picked = () => [...document.querySelectorAll("#sheetPick input:checked")].map((i) => i.value);
  document.getElementById("toggleAll").onclick = (e) => {
    const on = picked().length !== SHEETS.length;
    document.querySelectorAll("#sheetPick input").forEach((i) => (i.checked = on)); e.target.textContent = on ? "Select none" : "Select all";
  };
  const params = () => ({ organization_id: sel.value || undefined, include_children: document.getElementById("kids").checked, sheets: picked() });
  let data = null, cur = 0;
  async function fetchData(msg) {
    if (!picked().length) { UI.warn("Please tick at least one sheet."); return null; }
    return UI.run(() => API.call("export.org", params()), { loading: msg, success: false });
  }
  async function download() {
    const d = await fetchData("Collecting all data…"); if (!d) return;
    await UI.run(() => Exporter.workbook(d.title, d.sheets), { loading: "Building the Excel file…", success: `Downloaded – ${d.sheets.length} sheet(s), ${d.sheets.reduce((a, s) => a + s.rows.length, 0)} rows.` });
    show(d);
  }
  function show(d) {
    data = d; cur = 0;
    document.getElementById("out").classList.remove("d-none");
    document.getElementById("outTitle").textContent = d.title;
    document.getElementById("tabs").innerHTML = d.sheets.map((s, i) => `<li class="nav-item"><button class="nav-link text-nowrap ${i ? "" : "active"}" data-tab="${i}">${esc(s.name)} <span class="badge text-bg-light">${s.rows.length}</span></button></li>`).join("");
    document.querySelectorAll("[data-tab]").forEach((b) => (b.onclick = () => { cur = Number(b.dataset.tab); document.querySelectorAll("[data-tab]").forEach((x) => x.classList.toggle("active", x === b)); table(); }));
    table();
  }
  function table() {
    const s = data.sheets[cur];
    document.getElementById("oh").innerHTML = `<tr>${s.columns.map((c) => `<th class="text-nowrap">${esc(c)}</th>`).join("")}</tr>`;
    document.getElementById("ob").innerHTML = s.rows.length ? s.rows.slice(0, 100).map((r) => `<tr>${r.map((v) => `<td class="small text-nowrap">${esc(v ?? "")}</td>`).join("")}</tr>`).join("")
      : `<tr><td colspan="${s.columns.length}">${UI.empty("No rows in this sheet.", "inbox")}</td></tr>`;
    document.getElementById("of").textContent = `${s.rows.length} row(s)${s.rows.length > 100 ? " – the preview shows the first 100; downloads include everything" : ""}`;
  }
  document.getElementById("xlsx").onclick = download;
  document.getElementById("preview").onclick = async () => { const d = await fetchData("Loading preview…"); if (d) show(d); };
  document.getElementById("csv").onclick = () => { const s = data?.sheets[cur]; if (s) Exporter.csv(`${data.title} – ${s.name}`, s.columns, s.rows); };
  document.getElementById("pdf").onclick = () => { const s = data?.sheets[cur]; if (s) UI.run(() => Exporter.pdf(`${data.title} – ${s.name}`, s.columns, s.rows, { landscape: true }), { loading: "Preparing PDF…", success: "Download ready." }); };
});
