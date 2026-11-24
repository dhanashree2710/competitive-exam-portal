/* =====================================================================
   Exam wizard – 6 steps:
   1 Details · 2 Syllabus · 3 Questions (bank / random / AI / import / manual)
   4 Configuration · 5 Assign students · 6 Preview → Draft / Schedule / Publish
   ===================================================================== */
App.init({ roles: App.STAFF }).then(async (user) => {
  const el = document.getElementById("app");
  let examId = UI.qs("id"); let data = null; let tree = null; let step = 1;
  const STEPS = [[1, "Exam details", "card-text"], [2, "Syllabus", "diagram-3"], [3, "Questions", "patch-question"], [4, "Configuration", "sliders"], [5, "Assign students", "people"], [6, "Preview & publish", "rocket-takeoff"]];
  const TYPES = [["mcq_single", "MCQ – single correct"], ["mcq_multi", "MCQ – multiple correct"], ["true_false", "True / False"], ["numerical", "Numerical"], ["short_answer", "Short answer"], ["long_answer", "Long answer (manual)"]];
  const esc = UI.esc;

  el.innerHTML = `<div class="page-head mb-3"><div><a href="exams.html" class="small text-decoration-none"><i class="bi bi-arrow-left"></i> All exams</a>
      <h1 class="page-title mt-1"><i class="bi bi-magic me-2 text-primary"></i><span id="wzTitle">Create exam</span></h1>
      <div class="text-secondary small">Follow the steps – your work is saved as a draft after each step.</div></div></div>
    <div class="wizard-steps mb-3" id="wzSteps"></div>
    <div id="pane"></div>`;

  async function reload() {
    if (!examId) return;
    data = await API.call("exam.get", { id: examId });
    document.getElementById("wzTitle").innerHTML = `${esc(data.exam.title)} ${UI.badge(data.exam.status)}`;
  }
  const bp = () => (data?.exam?.blueprint && typeof data.exam.blueprint === "object" ? data.exam.blueprint : {});
  const scope = () => bp().scope || { subject_ids: [], chapter_ids: [], topic_ids: [] };
  const locked = () => (data?.attempts || 0) > 0;

  function renderSteps() {
    document.getElementById("wzSteps").innerHTML = STEPS.map(([n, label, icon]) => `<div class="wizard-step ${n === step ? "active" : ""} ${n < step && examId ? "done" : ""} ${n > 1 && !examId ? "locked" : ""}" data-step="${n}">
      <span class="num">${n < step && examId ? '<i class="bi bi-check2"></i>' : n}</span><span><i class="bi bi-${icon} me-1 d-none d-xl-inline"></i>${label}</span></div>`).join("");
  }
  document.getElementById("wzSteps").addEventListener("click", (e) => { const s = e.target.closest("[data-step]"); if (s) go(Number(s.dataset.step)); });

  async function go(n) {
    if (n > 1 && !examId) return UI.warn("Please fill in and save the exam details first.", "Step 1 first");
    step = n; renderSteps();
    const pane = document.getElementById("pane");
    pane.innerHTML = `<div class="text-center py-5"><span class="spinner-border text-primary"></span></div>`;
    try { await reload(); await PANES[n](pane); } catch (e) { pane.innerHTML = `<div class="card">${UI.empty(e.message || "Something went wrong.", "exclamation-circle")}</div>`; UI.handle(e); }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
  const navBar = (back, nextLabel = "Save & continue") => `<div class="d-flex gap-2 mt-3">${back ? `<button class="btn btn-light" data-back><i class="bi bi-arrow-left me-1"></i>Back</button>` : ""}
    <button class="btn btn-primary ms-auto" data-next>${nextLabel} <i class="bi bi-arrow-right ms-1"></i></button></div>`;
  const bindNav = (pane, onNext) => { pane.querySelector("[data-back]")?.addEventListener("click", () => go(step - 1)); pane.querySelector("[data-next]").addEventListener("click", onNext); };
  const opts = (list, sel) => list.map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(sel ?? "") ? "selected" : ""}>${esc(o.label)}</option>`).join("");

  // ---------------- STEP 1: details ----------------
  async function pane1(pane) {
    const e = data?.exam || { duration_minutes: 180, attempt_limit: 1, pass_percentage: 33, organization_id: user.organization_id };
    const [orgs, cats] = await Promise.all([App.options("organizations"), App.options("exam_categories")]);
    pane.innerHTML = `<div class="card wizard-pane"><div class="card-body"><div class="row g-3" id="f1">
      <div class="col-md-8"><label class="form-label required">Exam name</label><input class="form-control" name="title" value="${esc(e.title || "")}" placeholder="e.g. JEE Main Mock Test 1"></div>
      <div class="col-md-4"><label class="form-label required">Exam type</label><select class="form-select" name="exam_category_id"><option value="">— Select (JEE, NEET…) —</option>${opts(cats, e.exam_category_id)}</select>
        ${App.isAdmin() ? `<div class="form-text">Add new types on the <a href="syllabus.html">Syllabus</a> page.</div>` : ""}</div>
      <div class="col-md-4"><label class="form-label required">Organization</label><select class="form-select" name="organization_id">${opts(orgs, e.organization_id)}</select></div>
      <div class="col-md-4"><label class="form-label required">Duration (minutes)</label><input type="number" min="1" class="form-control" name="duration_minutes" value="${esc(e.duration_minutes ?? "")}"></div>
      <div class="col-md-4"><label class="form-label">Attempts allowed</label><input type="number" min="1" class="form-control" name="attempt_limit" value="${esc(e.attempt_limit ?? 1)}"></div>
      <div class="col-md-4"><label class="form-label">Opens at</label><input type="datetime-local" class="form-control" name="start_time" value="${esc(UI.toLocalInput(e.start_time))}"><div class="form-text">Needed to schedule. Leave empty to publish manually.</div></div>
      <div class="col-md-4"><label class="form-label">Closes at</label><input type="datetime-local" class="form-control" name="end_time" value="${esc(UI.toLocalInput(e.end_time))}"></div>
      <div class="col-md-4"><label class="form-label">Pass percentage</label><input type="number" min="0" max="100" class="form-control" name="pass_percentage" value="${esc(e.pass_percentage ?? 33)}"></div>
      <div class="col-12"><label class="form-label">Description</label><textarea class="form-control" rows="2" name="description">${esc(e.description || "")}</textarea></div>
      <div class="col-12"><label class="form-label">Instructions for students</label><textarea class="form-control" rows="4" name="instructions" placeholder="Each correct answer carries 4 marks…">${esc(e.instructions || "")}</textarea></div>
    </div>${navBar(false)}</div></div>`;
    bindNav(pane, async () => {
      const f = pane.querySelector("#f1"); const v = Object.fromEntries([...f.querySelectorAll("[name]")].map((i) => [i.name, i.value.trim()]));
      const missing = [["title", "Exam name"], ["exam_category_id", "Exam type"], ["organization_id", "Organization"], ["duration_minutes", "Duration"]].filter(([k]) => !v[k]).map(([, l]) => l);
      if (missing.length) return UI.warn(`Please fill in: ${missing.join(", ")}.`);
      if (!(Number(v.duration_minutes) >= 1)) return UI.warn("Duration must be at least 1 minute.");
      v.start_time = UI.fromLocalInput(v.start_time); v.end_time = UI.fromLocalInput(v.end_time);
      if (v.start_time && v.end_time && new Date(v.end_time) <= new Date(v.start_time)) return UI.warn("The closing time must be after the opening time.");
      ["duration_minutes", "attempt_limit", "pass_percentage"].forEach((k) => (v[k] = v[k] === "" ? null : Number(v[k])));
      const r = await UI.run(() => API.call("crud.save", { table: "exams", id: examId || undefined, data: v }), { loading: "Saving…", success: examId ? "Details saved." : "Exam created as a draft." });
      if (!r) return;
      examId = r.row.id; history.replaceState(null, "", `?id=${examId}`); tree = null;
      go(2);
    });
  }

  // ---------------- STEP 2: syllabus ----------------
  async function pane2(pane) {
    const cat = data.exam.exam_category_id;
    if (!cat) { pane.innerHTML = `<div class="card">${UI.empty("Choose the exam type (JEE, NEET…) in step 1 first.", "arrow-left")}</div>`; return; }
    tree = await API.call("syllabus.tree", { exam_category_id: cat });
    tree.units = tree.units || [];
    const sel = bp().selection || { chapters: [], topics: [] };
    const chosenC = new Set(sel.chapters || []), chosenT = new Set(sel.topics || []);
    const topicsOf = (cid) => tree.topics.filter((t) => t.chapter_id === cid);
    const cb = (attrs, label, cls, checked) => `<div class="form-check ${cls}"><input class="form-check-input" type="checkbox" ${attrs} ${checked ? "checked" : ""}><label class="form-check-label">${esc(label)}</label></div>`;
    const chapterHtml = (c, sid) => cb(`data-level="chapter" data-s="${sid}" data-u="${c.unit_id || ""}" data-c="${c.id}"`, `${c.name}${c.weightage ? ` (${c.weightage}%)` : ""}`, "syl-chapter", chosenC.has(c.id))
      + topicsOf(c.id).map((t) => cb(`data-level="topic" data-s="${sid}" data-u="${c.unit_id || ""}" data-c="${c.id}" data-t="${t.id}"`, t.name, "syl-topic", chosenT.has(t.id))).join("");
    const html = tree.subjects.length ? tree.subjects.map((s) => {
      const units = tree.units.filter((u) => u.subject_id === s.id);
      const chs = tree.chapters.filter((c) => c.subject_id === s.id);
      return `<div class="mb-2">${cb(`data-level="subject" data-s="${s.id}"`, s.name, "syl-subject", false)}
        ${units.map((u) => cb(`data-level="unit" data-s="${s.id}" data-u="${u.id}"`, u.name, "syl-unit", false) + chs.filter((c) => c.unit_id === u.id).map((c) => chapterHtml(c, s.id)).join("")).join("")}
        ${chs.filter((c) => !c.unit_id || !units.some((u) => u.id === c.unit_id)).map((c) => chapterHtml(c, s.id)).join("")}</div>`;
    }).join("") : UI.empty("This exam type has no syllabus yet. Add subjects and chapters on the Syllabus page, or skip this step to use the whole question bank.", "diagram-3");
    pane.innerHTML = `<div class="card wizard-pane"><div class="card-header d-flex align-items-center">Choose what this exam covers
        <div class="ms-auto d-flex gap-2"><button class="btn btn-sm btn-light" data-all>Select all</button><button class="btn btn-sm btn-light" data-none>Clear</button></div></div>
      <div class="card-body"><div class="small text-secondary mb-2">Subject → Unit → Chapter → Topic. Ticking a subject or unit selects everything inside it.</div>
      <div class="syl-tree border rounded p-3">${html}</div><div class="small mt-2" id="sylCount"></div>${navBar(true)}</div></div>`;
    const box = pane.querySelector(".syl-tree");
    const all = (q) => [...box.querySelectorAll(q)];
    const refresh = () => {
      all('[data-level="chapter"]').forEach((c) => { const ts = all(`[data-level="topic"][data-c="${c.dataset.c}"]`); if (ts.length) { const n = ts.filter((t) => t.checked).length; c.checked = n === ts.length; c.indeterminate = n > 0 && n < ts.length; } });
      const agg = (parent, kids) => { const n = kids.filter((k) => k.checked).length, p = kids.filter((k) => k.indeterminate).length; parent.checked = kids.length > 0 && n === kids.length; parent.indeterminate = !parent.checked && (n > 0 || p > 0); };
      all('[data-level="unit"]').forEach((u) => agg(u, all(`[data-level="chapter"][data-u="${u.dataset.u}"]`)));
      all('[data-level="subject"]').forEach((s) => agg(s, all(`[data-level="chapter"][data-s="${s.dataset.s}"]`)));
      const nc = all('[data-level="chapter"]').filter((c) => c.checked || c.indeterminate).length;
      pane.querySelector("#sylCount").innerHTML = nc ? `<i class="bi bi-check2-circle text-success"></i> ${nc} chapter(s) selected` : `<span class="text-secondary">Nothing selected – the whole question bank will be used.</span>`;
    };
    box.addEventListener("change", (e) => {
      const t = e.target; const lv = t.dataset.level;
      const kids = lv === "subject" ? all(`[data-s="${t.dataset.s}"]:not([data-level="subject"])`) : lv === "unit" ? all(`[data-u="${t.dataset.u}"]:not([data-level="unit"])`) : lv === "chapter" ? all(`[data-level="topic"][data-c="${t.dataset.c}"]`) : [];
      kids.forEach((k) => { k.checked = t.checked; k.indeterminate = false; });
      refresh();
    });
    pane.querySelector("[data-all]").onclick = () => { all("input").forEach((i) => (i.checked = true)); refresh(); };
    pane.querySelector("[data-none]").onclick = () => { all("input").forEach((i) => { i.checked = false; i.indeterminate = false; }); refresh(); };
    refresh();
    bindNav(pane, async () => {
      const chapters = all('[data-level="chapter"]').filter((c) => c.checked).map((c) => c.dataset.c);
      const topics = all('[data-level="topic"]').filter((c) => c.checked).map((c) => c.dataset.t);
      // smallest filter that matches the selection (whole subjects, whole chapters, or single topics)
      const sc = { subject_ids: [], chapter_ids: [], topic_ids: [] };
      all('[data-level="subject"]').forEach((s) => {
        const chs = all(`[data-level="chapter"][data-s="${s.dataset.s}"]`);
        if (s.checked && chs.length) return sc.subject_ids.push(s.dataset.s);
        chs.forEach((c) => {
          if (c.checked) sc.chapter_ids.push(c.dataset.c);
          else if (c.indeterminate) all(`[data-level="topic"][data-c="${c.dataset.c}"]`).filter((t) => t.checked).forEach((t) => sc.topic_ids.push(t.dataset.t));
        });
      });
      const blueprint = { ...bp(), selection: { chapters, topics }, scope: sc };
      if (await UI.run(() => API.call("crud.save", { table: "exams", id: examId, data: { blueprint } }), { loading: "Saving syllabus…", success: "Syllabus saved." })) go(3);
    });
  }

  // ---------------- STEP 3: questions ----------------
  async function pane3(pane) {
    const sc = scope(); const scopeEmpty = !sc.subject_ids.length && !sc.chapter_ids.length && !sc.topic_ids.length;
    if (!tree && data.exam.exam_category_id) { tree = await API.call("syllabus.tree", { exam_category_id: data.exam.exam_category_id }); tree.units = tree.units || []; }
    const T = tree || { subjects: [], chapters: [], topics: [], units: [] };
    const inScopeCh = T.chapters.filter((c) => scopeEmpty || sc.subject_ids.includes(c.subject_id) || sc.chapter_ids.includes(c.id) || T.topics.some((t) => t.chapter_id === c.id && sc.topic_ids.includes(t.id)));
    const lockMsg = locked() ? `<div class="alert alert-warning"><i class="bi bi-lock me-1"></i>Students have already attempted this exam, so questions can't be changed.</div>` : "";
    pane.innerHTML = `${lockMsg}<div class="row g-3 wizard-pane">
      <div class="col-xl-7"><div class="card"><div class="card-header">
        <ul class="nav nav-pills small flex-wrap" id="qTabs">${[["bank", "From bank", "collection"], ["random", "Random", "shuffle"], ["ai", "AI generate", "stars"], ["import", "Import file", "file-earmark-arrow-up"], ["manual", "Write one", "pencil"]]
          .map(([k, l, i], n) => `<li class="nav-item"><button class="nav-link ${n ? "" : "active"}" data-tab="${k}"><i class="bi bi-${i} me-1"></i>${l}</button></li>`).join("")}</ul></div>
        <div class="card-body" id="qTab"></div></div></div>
      <div class="col-xl-5"><div class="card"><div class="card-header d-flex">In this exam <span class="ms-auto" id="qSum"></span></div>
        <div class="list-group list-group-flush" id="qList" style="max-height:62vh;overflow:auto"></div></div></div></div>${navBar(true)}`;
    const chapterOpts = `<option value="">— Any chapter in the syllabus —</option>` + inScopeCh.map((c) => `<option value="${c.id}" data-s="${c.subject_id}">${esc(T.subjects.find((s) => s.id === c.subject_id)?.name || "")} › ${esc(c.name)}</option>`).join("");
    const typeOpts = TYPES.map(([v, l]) => `<option value="${v}">${l}</option>`).join("");

    async function loadList() {
      const r = await API.call("exam.preview", { exam_id: examId });
      const total = r.questions.reduce((s, q) => s + Number(q.marks || 0), 0);
      pane.querySelector("#qSum").innerHTML = `<span class="badge text-bg-primary">${r.questions.length} questions</span> <span class="badge text-bg-light">${UI.num(total)} marks</span>`;
      pane.querySelector("#qList").innerHTML = r.questions.length ? r.questions.map((q, i) => `<div class="list-group-item d-flex gap-2 align-items-start">
        <span class="badge text-bg-light">${i + 1}</span><div class="flex-grow-1 small"><div class="clamp-2">${esc(UI.stripHtml(q.text))}</div>
        <div class="text-secondary">${esc(q.subject?.name || "")}${q.chapter ? " › " + esc(q.chapter.name) : ""} · ${UI.num(q.marks)} marks ${q.difficulty ? UI.badge(q.difficulty) : ""}</div></div>
        ${locked() ? "" : `<button class="btn btn-sm btn-light text-danger" data-rmq="${q.eq_id}" title="Remove"><i class="bi bi-x-lg"></i></button>`}</div>`).join("")
        : UI.empty("No questions yet. Add some using the tabs on the left.", "patch-question");
      pane.querySelectorAll("[data-rmq]").forEach((b) => (b.onclick = async () => { if (await UI.run(() => API.call("exam.removeQuestion", { id: b.dataset.rmq }), { loading: false })) { loadList(); if (curTab === "bank") TABS.bank(); } }));
    }
    const addIds = async (ids, msg) => { if (!ids.length) return false; const r = await UI.run(() => API.call("exam.addQuestions", { exam_id: examId, question_ids: ids }), { loading: "Adding…", success: msg }); if (r) await loadList(); return !!r; };
    const box = pane.querySelector("#qTab"); let curTab = "bank";
    const TABS = {
      async bank() {
        box.innerHTML = `<div class="row g-2 mb-2"><div class="col-md-6"><input class="form-control form-control-sm" placeholder="Search question text…" data-s></div>
          <div class="col-6 col-md-3"><select class="form-select form-select-sm" data-d><option value="">Any level</option><option value="easy">Easy</option><option value="medium">Medium</option><option value="hard">Hard</option></select></div>
          <div class="col-6 col-md-3"><select class="form-select form-select-sm" data-st><option value="">Any status</option><option value="approved">Approved</option><option value="published">Published</option><option value="draft">Draft</option></select></div></div>
          <div class="small text-secondary mb-2">${scopeEmpty ? "Showing the whole question bank (no syllabus selected)." : "Showing questions from the selected syllabus."}</div>
          <div class="border rounded" style="max-height:44vh;overflow:auto" data-list></div>
          <div class="d-flex mt-2"><span class="small text-secondary" data-info></span><button class="btn btn-primary btn-sm ms-auto" data-add ${locked() ? "disabled" : ""}>Add selected (<span data-n>0</span>)</button></div>`;
        const picked = new Set();
        const load = async () => {
          const list = box.querySelector("[data-list]"); list.innerHTML = `<div class="p-3 text-center"><span class="spinner-border spinner-border-sm"></span></div>`;
          try {
            const r = await API.call("questions.inScope", { ...sc, exam_id: examId, search: box.querySelector("[data-s]").value, difficulty: box.querySelector("[data-d]").value, status: box.querySelector("[data-st]").value });
            list.innerHTML = r.rows.length ? r.rows.map((q) => `<label class="d-flex gap-2 p-2 border-bottom ${q.in_exam ? "opacity-50" : ""}"><input type="checkbox" class="form-check-input mt-1" value="${q.id}" ${q.in_exam ? "checked disabled" : picked.has(q.id) ? "checked" : ""}>
              <div class="small flex-grow-1"><div class="clamp-2">${esc(UI.stripHtml(q.question_text))}</div><div class="text-secondary">${esc(q.subject?.name || "—")}${q.chapter ? " › " + esc(q.chapter.name) : ""} · ${esc(q.question_type.replace(/_/g, " "))} · ${UI.num(q.marks)} marks ${UI.badge(q.status)} ${q.difficulty ? UI.badge(q.difficulty) : ""}${q.in_exam ? " · already added" : ""}</div></div></label>`).join("")
              : UI.empty("No questions found. Try the Random, AI or Import tabs.", "search");
            box.querySelector("[data-info]").textContent = r.rows.length >= 300 ? "Showing the newest 300 – use search to narrow down." : `${r.rows.length} found`;
            list.querySelectorAll("input:not([disabled])").forEach((c) => c.addEventListener("change", () => { c.checked ? picked.add(c.value) : picked.delete(c.value); box.querySelector("[data-n]").textContent = picked.size; }));
          } catch (e) { list.innerHTML = UI.empty(e.message, "exclamation-circle"); }
        };
        box.querySelector("[data-s]").addEventListener("input", UI.debounce(load));
        box.querySelectorAll("select").forEach((s) => s.addEventListener("change", load));
        box.querySelector("[data-add]").onclick = async () => { if (!picked.size) return UI.warn("Tick at least one question."); if (await addIds([...picked])) { picked.clear(); box.querySelector("[data-n]").textContent = 0; load(); } };
        load();
      },
      async random() {
        box.innerHTML = `<p class="small text-secondary">Pick questions at random from ${scopeEmpty ? "the whole question bank" : "the selected syllabus"}. Set how many of each level you want.</p>
          <div class="row g-2">${[["easy", "Easy"], ["medium", "Medium"], ["hard", "Hard"], ["any", "Any level"]].map(([k, l]) => `<div class="col-6 col-md-3"><label class="form-label">${l}</label><input type="number" min="0" max="200" class="form-control" data-mix="${k}" value="${k === "medium" ? 10 : 0}"></div>`).join("")}</div>
          <div class="form-check mt-3"><input class="form-check-input" type="checkbox" id="incDraft"><label class="form-check-label" for="incDraft">Include draft questions (not yet approved)</label></div>
          <button class="btn btn-primary mt-3" data-go ${locked() ? "disabled" : ""}><i class="bi bi-shuffle me-1"></i>Pick questions</button>`;
        box.querySelector("[data-go]").onclick = async () => {
          const mix = Object.fromEntries([...box.querySelectorAll("[data-mix]")].map((i) => [i.dataset.mix, Number(i.value) || 0]));
          if (!Object.values(mix).some((n) => n > 0)) return UI.warn("Enter how many questions to pick.");
          const r = await UI.run(() => API.call("exam.autoPick", { exam_id: examId, ...sc, match_any: true, mix, include_drafts: box.querySelector("#incDraft").checked }), { loading: "Picking…" });
          if (r) loadList();
        };
      },
      async ai() {
        box.innerHTML = `<div class="row g-2">
          <div class="col-md-6"><label class="form-label">Chapter</label><select class="form-select" data-ch>${chapterOpts}</select></div>
          <div class="col-md-6"><label class="form-label">Topic</label><select class="form-select" data-tp><option value="">— Any topic —</option></select></div>
          <div class="col-md-6"><label class="form-label">Question type</label><select class="form-select" data-type>${typeOpts}</select></div>
          <div class="col-6 col-md-3"><label class="form-label">Difficulty</label><select class="form-select" data-diff><option value="easy">Easy</option><option value="medium" selected>Medium</option><option value="hard">Hard</option></select></div>
          <div class="col-6 col-md-3"><label class="form-label">How many</label><input type="number" class="form-control" min="1" max="20" value="5" data-count></div>
          <div class="col-md-6"><label class="form-label">Language</label><select class="form-select" data-lang><option value="en">English</option><option value="hi">Hindi</option></select></div>
          <div class="col-md-6"><label class="form-label">Marks each</label><input type="number" class="form-control" min="0.25" step="0.25" value="4" data-marks></div>
          <div class="col-12"><label class="form-label">Topic description (optional)</label><input class="form-control" data-text placeholder="e.g. Projectile motion with numerical problems"></div>
          <div class="col-12"><label class="form-label">Study material (optional)</label><input type="file" class="form-control" accept=".pdf,.docx,.txt" data-doc><div class="form-text">The AI will write questions only from this document.</div></div></div>
          <button class="btn btn-primary mt-3" data-go ${locked() ? "disabled" : ""}><i class="bi bi-stars me-1"></i>Generate</button>`;
        const chSel = box.querySelector("[data-ch]"), tpSel = box.querySelector("[data-tp]");
        chSel.onchange = () => { tpSel.innerHTML = `<option value="">— Any topic —</option>` + T.topics.filter((t) => t.chapter_id === chSel.value).map((t) => `<option value="${t.id}">${esc(t.name)}</option>`).join(""); };
        box.querySelector("[data-go]").onclick = async () => {
          const chOpt = chSel.selectedOptions[0];
          const p = { chapter_id: chSel.value || null, subject_id: chOpt?.dataset.s || (sc.subject_ids[0] || null), topic_id: tpSel.value || null,
            question_type: box.querySelector("[data-type]").value, difficulty: box.querySelector("[data-diff]").value, count: Number(box.querySelector("[data-count]").value) || 5,
            language: box.querySelector("[data-lang]").value, topic_text: box.querySelector("[data-text]").value.trim() || null };
          if (!p.subject_id && !p.chapter_id && !p.topic_text && !box.querySelector("[data-doc]").files[0]) return UI.warn("Choose a chapter, describe the topic, or upload study material.");
          const doc = box.querySelector("[data-doc]").files[0];
          if (doc) { const t = await UI.run(() => Docs.text(doc), { loading: "Reading document…", success: false }); if (!t) return; p.source_text = t; }
          const r = await UI.run(() => API.call("ai.generateQuestions", p), { loading: `AI is writing ${p.count} question(s)… up to a minute`, quiet: true });
          if (r) reviewAndAdd(r.questions, { subject_id: p.subject_id, chapter_id: p.chapter_id, topic_id: p.topic_id, marks: Number(box.querySelector("[data-marks]").value) || 1, source: "ai" });
        };
      },
      async import() {
        box.innerHTML = `<div class="mb-3"><label class="form-label">Excel / CSV question sheet</label>
            <div class="d-flex gap-2"><input type="file" class="form-control" accept=".xlsx,.xls,.csv" data-sheet><button class="btn btn-outline-primary text-nowrap" data-sgo>Import</button></div>
            <div class="form-text">Columns: question, type, option_a, option_b, option_c, option_d, answer, marks, negative_marks, difficulty, explanation. <a href="#" data-tpl>Download template</a></div></div>
          <hr><div><label class="form-label">Question paper (PDF / Word / image text) – AI extracts the questions</label>
            <div class="d-flex gap-2"><input type="file" class="form-control" accept=".pdf,.docx,.txt" data-paper><button class="btn btn-outline-primary text-nowrap" data-pgo>Extract</button></div>
            <div class="form-text">The original file is kept in the “uploads” bucket. You review every question before it's added.</div></div>`;
        box.querySelector("[data-tpl]").onclick = (e) => { e.preventDefault(); Exporter.csv("question_template", ["question", "type", "option_a", "option_b", "option_c", "option_d", "answer", "marks", "negative_marks", "difficulty", "explanation"],
          [["What is 2 + 2?", "mcq_single", "3", "4", "5", "6", "B", 4, 1, "easy", "2 + 2 = 4"], ["Sound needs a medium to travel.", "true_false", "", "", "", "", "true", 4, 1, "easy", ""], ["g on Earth (m/s²)?", "numerical", "", "", "", "", "9.8", 4, 0, "medium", "±0.1 accepted"]]); };
        box.querySelector("[data-sgo]").onclick = async () => {
          const f = box.querySelector("[data-sheet]").files[0]; if (!f) return UI.warn("Please choose an Excel or CSV file.");
          const rows = await UI.run(() => Docs.rows(f), { loading: "Reading sheet…", success: false }); if (!rows) return;
          const items = rows.map((r) => {
            const type = String(r.type || "mcq_single").trim().toLowerCase().replace(/\s+/g, "_");
            const options = ["a", "b", "c", "d", "e", "f"].map((k, i) => ({ key: String.fromCharCode(65 + i), text: String(r[`option_${k}`] ?? r[k] ?? "").trim() })).filter((o) => o.text);
            let ans = String(r.answer ?? r.correct ?? "").trim();
            const correct_answer = type === "mcq_multi" ? ans.split(/[,;\s]+/).filter(Boolean).map((x) => x.toUpperCase()) : type === "numerical" ? { value: Number(ans), tolerance: Number(r.tolerance || 0) } : type === "short_answer" ? ans.split("|").map((x) => x.trim()) : type.startsWith("mcq") ? ans.toUpperCase() : ans.toLowerCase();
            return { question_text: String(r.question || r.question_text || "").trim(), question_type: type, options: type.startsWith("mcq") ? options : null, correct_answer,
              marks: Number(r.marks) || 1, negative_marks: Number(r.negative_marks) || 0, difficulty: ["easy", "medium", "hard"].includes(String(r.difficulty).toLowerCase()) ? String(r.difficulty).toLowerCase() : null, explanation: r.explanation || null, source: "import" };
          }).filter((x) => x.question_text);
          if (!items.length) return UI.warn("No questions were found. The first row must be the header (question, type, option_a…).");
          UI.upload(f, "document", {}, "Saving the original file…");
          reviewAndAdd(items, { source: "import" });
        };
        box.querySelector("[data-pgo]").onclick = async () => {
          const f = box.querySelector("[data-paper]").files[0]; if (!f) return UI.warn("Please choose a PDF or Word file.");
          const text = await UI.run(() => Docs.text(f), { loading: "Reading document…", success: false }); if (!text) return;
          if (text.trim().length < 30) return UI.warn("No readable text was found in this file. Scanned images can't be read – please use a text PDF or Word file.");
          API.upload(f, "document").catch(() => {});
          const r = await UI.run(() => API.call("ai.generateQuestions", { source_text: text, count: 20, question_type: "mcq_single", difficulty: "medium",
            instructions: "Extract the questions exactly as written in the material (keep wording and options). Only if the material has no questions, write new ones from it.", subject_id: sc.subject_ids[0] || null }),
            { loading: "AI is extracting questions… up to a minute", quiet: true });
          if (r) reviewAndAdd(r.questions, { source: "import" });
        };
      },
      async manual() {
        box.innerHTML = `<div class="row g-2" id="mf">
          <div class="col-12"><label class="form-label required">Question</label><textarea class="form-control" rows="3" name="question_text"></textarea></div>
          <div class="col-md-6"><label class="form-label">Type</label><select class="form-select" name="question_type"><option value="mcq_single">MCQ – single correct</option><option value="true_false">True / False</option><option value="numerical">Numerical</option></select></div>
          <div class="col-md-6"><label class="form-label">Chapter</label><select class="form-select" name="chapter_id">${chapterOpts}</select></div>
          <div class="col-12" data-mcq>${["A", "B", "C", "D"].map((k) => `<div class="input-group mb-2"><span class="input-group-text"><input class="form-check-input mt-0" type="radio" name="ans" value="${k}" ${k === "A" ? "checked" : ""}></span><span class="input-group-text">${k}</span><input class="form-control" data-opt="${k}" placeholder="Option ${k}"></div>`).join("")}<div class="form-text">Tick the correct option.</div></div>
          <div class="col-md-6 d-none" data-tf><label class="form-label">Correct answer</label><select class="form-select" name="tf"><option value="true">True</option><option value="false">False</option></select></div>
          <div class="col-md-6 d-none" data-num><label class="form-label">Correct value</label><input type="number" step="any" class="form-control" name="num"></div>
          <div class="col-6 col-md-3"><label class="form-label">Marks</label><input type="number" class="form-control" name="marks" value="4" min="0.25" step="0.25"></div>
          <div class="col-6 col-md-3"><label class="form-label">Difficulty</label><select class="form-select" name="difficulty"><option value="easy">Easy</option><option value="medium" selected>Medium</option><option value="hard">Hard</option></select></div>
          <div class="col-12"><label class="form-label">Explanation (optional)</label><input class="form-control" name="explanation"></div></div>
          <button class="btn btn-primary mt-3" data-go ${locked() ? "disabled" : ""}><i class="bi bi-plus-lg me-1"></i>Save to bank & add</button>`;
        const mf = box.querySelector("#mf"); const typ = mf.querySelector('[name="question_type"]');
        typ.onchange = () => { mf.querySelector("[data-mcq]").classList.toggle("d-none", typ.value !== "mcq_single"); mf.querySelector("[data-tf]").classList.toggle("d-none", typ.value !== "true_false"); mf.querySelector("[data-num]").classList.toggle("d-none", typ.value !== "numerical"); };
        box.querySelector("[data-go]").onclick = async () => {
          const v = (n) => mf.querySelector(`[name="${n}"]`)?.value.trim();
          if (!v("question_text")) return UI.warn("Please write the question.");
          const t = typ.value; const ch = T.chapters.find((c) => c.id === v("chapter_id"));
          const q = { question_text: v("question_text"), question_type: t, marks: Number(v("marks")) || 1, difficulty: v("difficulty"), explanation: v("explanation") || null, status: "approved", source: "manual",
            chapter_id: ch?.id || null, subject_id: ch?.subject_id || sc.subject_ids[0] || null, organization_id: data.exam.organization_id };
          if (t === "mcq_single") { q.options = ["A", "B", "C", "D"].map((k) => ({ key: k, text: mf.querySelector(`[data-opt="${k}"]`).value.trim() })).filter((o) => o.text); q.correct_answer = mf.querySelector('[name="ans"]:checked').value; if (q.options.length < 2) return UI.warn("Fill in at least two options."); }
          if (t === "true_false") q.correct_answer = v("tf");
          if (t === "numerical") { if (v("num") === "") return UI.warn("Enter the correct value."); q.correct_answer = { value: Number(v("num")), tolerance: 0 }; }
          const r = await UI.run(() => API.call("crud.save", { table: "questions", data: q }), { loading: "Saving…", success: false });
          if (r && await addIds([r.row.id], "Question saved to the bank and added to the exam.")) TABS.manual();
        };
      },
    };
    async function reviewAndAdd(questions, extra) {
      const m = UI.modal({ title: `Review ${questions.length} question(s)`, size: "xl",
        body: `<div class="alert alert-warning small"><i class="bi bi-exclamation-triangle me-1"></i>Check each question and answer. Ticked questions are saved to the question bank as <b>approved</b> and added to this exam.</div>
          <div class="form-check mb-2"><input class="form-check-input" type="checkbox" id="rvAll" checked><label class="form-check-label" for="rvAll">Select all</label></div>
          ${questions.map((q, i) => `<div class="card mb-2 border no-hover"><div class="card-body py-2"><label class="d-flex gap-2"><input type="checkbox" class="form-check-input mt-1" data-q="${i}" checked>
            <div class="flex-grow-1"><div class="question-text">${UI.safeHtml(q.question_text)}</div>
            ${(q.options || []).length ? `<div class="small">${q.options.map((o) => `<span class="me-3 ${[].concat(q.correct_answer).map(String).includes(o.key) ? "text-success fw-bold" : ""}">${esc(o.key)}. ${esc(o.text)}</span>`).join("")}</div>`
              : `<div class="small text-success">Answer: ${esc(typeof q.correct_answer === "object" ? (q.correct_answer?.value ?? JSON.stringify(q.correct_answer)) : q.correct_answer ?? "graded manually")}</div>`}</div></label></div></div>`).join("")}`,
        footer: `<button class="btn btn-light" data-bs-dismiss="modal">Cancel</button><button class="btn btn-primary" data-save><i class="bi bi-check2 me-1"></i>Save & add selected</button>` });
      m.el.querySelector("#rvAll").onchange = (e) => m.el.querySelectorAll("[data-q]").forEach((c) => (c.checked = e.target.checked));
      m.el.querySelector("[data-save]").onclick = async () => {
        const items = [...m.el.querySelectorAll("[data-q]:checked")].map((c) => ({ ...questions[Number(c.dataset.q)], ...(extra.marks ? { marks: extra.marks } : {}), source: extra.source }));
        if (!items.length) return UI.warn("Tick at least one question.");
        const r = await UI.run(() => API.call("questions.bulkCreate", { items, status: "approved", organization_id: data.exam.organization_id, subject_id: extra.subject_id || null, chapter_id: extra.chapter_id || null, topic_id: extra.topic_id || null }), { loading: "Saving…", quiet: true });
        if (!r) return;
        m.close();
        if (r.ids?.length) await addIds(r.ids, r.message + " Added to the exam."); else UI.warn(r.message);
      };
    }
    pane.querySelector("#qTabs").addEventListener("click", (e) => { const b = e.target.closest("[data-tab]"); if (!b) return; curTab = b.dataset.tab; pane.querySelectorAll("#qTabs .nav-link").forEach((x) => x.classList.toggle("active", x === b)); TABS[curTab](); });
    TABS.bank(); loadList();
    bindNav(pane, async () => { const r = await API.call("exam.preview", { exam_id: examId }); if (!r.questions.length) return UI.warn("Add at least one question before continuing."); go(4); });
  }

  // ---------------- STEP 4: configuration ----------------
  async function pane4(pane) {
    const r = await API.call("exam.preview", { exam_id: examId }); const e = data.exam; const neg = e.settings?.negative_marks;
    pane.innerHTML = `${locked() ? `<div class="alert alert-warning"><i class="bi bi-lock me-1"></i>Students have attempted this exam – marks and sections are locked.</div>` : ""}
      <div class="row g-3 wizard-pane"><div class="col-lg-4"><div class="card"><div class="card-header">Rules</div><div class="card-body">
        <div class="form-check form-switch mb-2"><input class="form-check-input" type="checkbox" id="cNeg" ${e.negative_marking ? "checked" : ""}><label class="form-check-label" for="cNeg">Negative marking</label></div>
        <div class="mb-3 ms-4" id="negBox"><label class="form-label small">Marks deducted per wrong answer</label><input type="number" min="0" step="0.25" class="form-control form-control-sm" id="cNegVal" value="${esc(neg ?? "")}" placeholder="Use each question's own value"></div>
        <div class="form-check form-switch mb-2"><input class="form-check-input" type="checkbox" id="cShQ" ${e.shuffle_questions ? "checked" : ""}><label class="form-check-label" for="cShQ">Shuffle question order for each student</label></div>
        <div class="form-check form-switch mb-2"><input class="form-check-input" type="checkbox" id="cShO" ${e.shuffle_options ? "checked" : ""}><label class="form-check-label" for="cShO">Shuffle answer options</label></div>
        <div class="form-check form-switch mb-2"><input class="form-check-input" type="checkbox" id="cRes" ${e.show_result_immediately ? "checked" : ""}><label class="form-check-label" for="cRes">Show score right after submitting</label></div>
        <hr><label class="form-label small">Set marks for all questions</label>
        <div class="input-group input-group-sm mb-2"><input type="number" min="0.25" step="0.25" class="form-control" id="allMarks" placeholder="e.g. 4"><button class="btn btn-outline-primary" id="applyMarks">Apply</button></div>
        <label class="form-label small">Sections</label><div class="d-flex gap-2"><button class="btn btn-sm btn-outline-primary" id="secSubj">By subject</button><button class="btn btn-sm btn-light" id="secClear">Clear</button></div>
        <div class="form-check mt-2"><input class="form-check-input" type="checkbox" id="grpSec" checked><label class="form-check-label small" for="grpSec">Keep questions grouped by section</label></div>
      </div></div></div>
      <div class="col-lg-8"><div class="card"><div class="card-header d-flex">Questions <span class="ms-auto small" id="cfgTotal"></span></div><div class="table-responsive" style="max-height:60vh">
        <table class="table table-sm mb-0"><thead><tr><th>#</th><th>Question</th><th>Subject</th><th style="width:130px">Section</th><th style="width:90px">Marks</th></tr></thead><tbody>
        ${r.questions.map((q, i) => `<tr data-eq="${q.eq_id}" data-subject="${esc(q.subject?.name || "")}"><td>${i + 1}</td><td class="small"><div class="clamp-2">${esc(UI.stripHtml(q.text))}</div>${q.difficulty ? UI.badge(q.difficulty) : ""}</td>
          <td class="small">${esc(q.subject?.name || "—")}</td><td><input class="form-control form-control-sm" data-sec value="${esc(q.section || "")}" ${locked() ? "disabled" : ""}></td>
          <td><input type="number" min="0.25" step="0.25" class="form-control form-control-sm" data-mk value="${esc(q.marks)}" ${locked() ? "disabled" : ""}></td></tr>`).join("")}</tbody></table></div></div></div></div>${navBar(true)}`;
    const total = () => { const t = [...pane.querySelectorAll("[data-mk]")].reduce((s, i) => s + (Number(i.value) || 0), 0); pane.querySelector("#cfgTotal").innerHTML = `Total: <b>${UI.num(t)}</b> marks · ${r.questions.length} questions`; };
    const negToggle = () => pane.querySelector("#negBox").classList.toggle("d-none", !pane.querySelector("#cNeg").checked);
    pane.querySelector("#cNeg").onchange = negToggle; negToggle(); total();
    pane.addEventListener("input", (ev) => { if (ev.target.matches("[data-mk]")) total(); });
    pane.querySelector("#applyMarks").onclick = () => { const v = pane.querySelector("#allMarks").value; if (!(Number(v) > 0)) return UI.warn("Enter marks greater than 0."); pane.querySelectorAll("[data-mk]").forEach((i) => (i.value = v)); total(); };
    pane.querySelector("#secSubj").onclick = () => pane.querySelectorAll("tr[data-eq]").forEach((tr) => (tr.querySelector("[data-sec]").value = tr.dataset.subject || "General"));
    pane.querySelector("#secClear").onclick = () => pane.querySelectorAll("[data-sec]").forEach((i) => (i.value = ""));
    bindNav(pane, async () => {
      let rows = [...pane.querySelectorAll("tr[data-eq]")].map((tr, i) => ({ id: tr.dataset.eq, marks: Number(tr.querySelector("[data-mk]").value), section: tr.querySelector("[data-sec]").value.trim() || null, i }));
      if (rows.some((x) => !(x.marks > 0))) return UI.warn("Every question needs marks greater than 0.");
      if (pane.querySelector("#grpSec").checked) { const order = [...new Set(rows.map((x) => x.section || "~"))]; rows.sort((a, b) => order.indexOf(a.section || "~") - order.indexOf(b.section || "~") || a.i - b.i); }
      const negVal = pane.querySelector("#cNegVal").value;
      const p = { exam_id: examId, negative_marking: pane.querySelector("#cNeg").checked, negative_marks: negVal === "" ? null : Number(negVal),
        shuffle_questions: pane.querySelector("#cShQ").checked, shuffle_options: pane.querySelector("#cShO").checked, show_result_immediately: pane.querySelector("#cRes").checked };
      if (!locked()) p.items = rows.map((x, i) => ({ id: x.id, marks: x.marks, section: x.section, order_index: i + 1 }));
      if (await UI.run(() => API.call("exam.configure", p), { loading: "Saving…" })) go(5);
    });
  }

  // ---------------- STEP 5: assign ----------------
  async function pane5(pane) {
    const org = data.exam.organization_id;
    const [batches, students] = await Promise.all([App.lookup("batches", { organization_id: org }), App.lookup("students", { organization_id: org })]);
    const assignedB = new Set(data.assignments.filter((a) => a.batch).map((a) => a.batch.id)), assignedU = new Set(data.assignments.filter((a) => a.user).map((a) => a.user.id));
    pane.innerHTML = `<div class="row g-3 wizard-pane"><div class="col-lg-7"><div class="card"><div class="card-header">Add batches / classes / students</div><div class="card-body">
        <label class="form-label">Batches</label><div class="border rounded p-2 mb-3" style="max-height:200px;overflow:auto">${batches.length ? batches.map((b) => `<div class="form-check"><input class="form-check-input" type="checkbox" value="${b.id}" id="b${b.id}" data-b ${assignedB.has(b.id) ? "checked disabled" : ""}><label class="form-check-label" for="b${b.id}">${esc(b.name)}${b.code ? ` <span class="text-secondary small">${esc(b.code)}</span>` : ""}${assignedB.has(b.id) ? ' <span class="badge text-bg-light">assigned</span>' : ""}</label></div>`).join("") : `<div class="small text-secondary">No batches in this organization yet. Create them on the <a href="batches.html">Batches</a> page.</div>`}</div>
        <label class="form-label">Individual students</label><input class="form-control form-control-sm mb-2" placeholder="Search name, email or roll no…" data-f>
        <select multiple class="form-select" size="8" data-u></select><div class="form-text">Ctrl/Cmd-click to choose several.</div>
        <button class="btn btn-primary mt-3" data-assign><i class="bi bi-person-plus me-1"></i>Assign selected</button></div></div></div>
      <div class="col-lg-5"><div class="card"><div class="card-header">Currently assigned</div><ul class="list-group list-group-flush">
        ${data.assignments.length ? data.assignments.map((a) => `<li class="list-group-item d-flex align-items-center gap-2"><i class="bi bi-${a.batch ? "people" : "person"} text-primary"></i>
          <div class="flex-grow-1">${a.batch ? `Batch: <b>${esc(a.batch.name)}</b>` : `<b>${esc(a.user?.full_name)}</b> <span class="small text-secondary">${esc(a.user?.email || "")}</span>`}</div>
          <button class="btn btn-sm btn-light text-danger" data-un="${a.id}"><i class="bi bi-x-lg"></i></button></li>`).join("") : `<li class="list-group-item">${UI.empty("Not assigned yet. Students only see exams assigned to them or their batch.", "people")}</li>`}</ul></div></div></div>${navBar(true, "Continue to preview")}`;
    const us = pane.querySelector("[data-u]");
    const fill = (q = "") => { q = q.toLowerCase(); us.innerHTML = students.filter((s) => !assignedU.has(s.id) && (!q || `${s.full_name} ${s.email} ${s.roll_number || ""}`.toLowerCase().includes(q))).map((s) => `<option value="${s.id}">${esc(s.full_name)} · ${esc(s.email)}${s.roll_number ? " · " + esc(s.roll_number) : ""}</option>`).join(""); };
    fill(); pane.querySelector("[data-f]").addEventListener("input", (e) => fill(e.target.value));
    pane.querySelector("[data-assign]").onclick = async () => {
      const batch_ids = [...pane.querySelectorAll("[data-b]:checked:not([disabled])")].map((c) => c.value);
      const user_ids = [...us.selectedOptions].map((o) => o.value);
      if (!batch_ids.length && !user_ids.length) return UI.warn("Tick a batch or choose students first.");
      if (await UI.run(() => API.call("exam.assign", { exam_id: examId, batch_ids, user_ids }), { loading: "Assigning…" })) { App.clearLookup(); go(5); }
    };
    pane.querySelectorAll("[data-un]").forEach((b) => (b.onclick = async () => { if (await UI.confirm("Remove this assignment?", { confirmText: "Remove", danger: true }) && await UI.run(() => API.call("exam.unassign", { id: b.dataset.un }))) go(5); }));
    bindNav(pane, () => { if (!data.assignments.length) UI.toast("Tip: assign the exam before publishing.", "warning"); go(6); });
  }

  // ---------------- STEP 6: preview & publish ----------------
  async function pane6(pane) {
    const e = data.exam; const r = await API.call("exam.preview", { exam_id: examId });
    const total = r.questions.reduce((s, q) => s + Number(q.marks || 0), 0);
    const by = (key) => Object.entries(r.questions.reduce((a, q) => { const k = key(q) || "—"; a[k] = (a[k] || 0) + 1; return a; }, {}));
    const checks = [[r.questions.length > 0, `${r.questions.length} questions · ${UI.num(total)} marks`], [data.assignments.length > 0, `${data.assignments.length} batch/student assignment(s)`],
      [!!e.duration_minutes, `${e.duration_minutes || "—"} minutes`], [!!e.start_time, e.start_time ? `Opens ${UI.fmtDateTime(e.start_time)}` : "No opening time (needed only to schedule)"]];
    const keys = (q) => [].concat(q.correct_answer ?? []).map(String);
    pane.innerHTML = `<div class="row g-3 wizard-pane"><div class="col-lg-4"><div class="card mb-3"><div class="card-header">Summary</div><div class="card-body small">
        <div class="fs-5 fw-bold mb-1">${esc(e.title)}</div><div class="text-secondary mb-2">${esc(e.exam_category?.name || "")} · ${esc(e.organization?.name || "")}</div>
        ${checks.map(([ok, t]) => `<div class="mb-1"><i class="bi bi-${ok ? "check-circle-fill text-success" : "exclamation-circle text-warning"} me-1"></i>${esc(t)}</div>`).join("")}
        <div class="mb-1"><i class="bi bi-${e.negative_marking ? "dash-circle text-danger" : "circle text-secondary"} me-1"></i>${e.negative_marking ? `Negative marking${e.settings?.negative_marks != null ? ` (−${UI.num(e.settings.negative_marks)})` : ""}` : "No negative marking"}</div>
        <hr><div class="fw-semibold">By subject</div>${by((q) => q.subject?.name).map(([k, n]) => `<div class="d-flex"><span>${esc(k)}</span><span class="ms-auto">${n}</span></div>`).join("")}
        <div class="fw-semibold mt-2">By difficulty</div>${by((q) => q.difficulty).map(([k, n]) => `<div class="d-flex"><span class="text-capitalize">${esc(k)}</span><span class="ms-auto">${n}</span></div>`).join("")}
      </div></div>
      <div class="card"><div class="card-body d-grid gap-2">
        <button class="btn btn-success" data-st="live"><i class="bi bi-broadcast me-1"></i>Publish now</button>
        <button class="btn btn-outline-primary" data-st="scheduled"><i class="bi bi-calendar-check me-1"></i>Schedule${e.start_time ? ` for ${UI.fmtDateTime(e.start_time)}` : ""}</button>
        <button class="btn btn-light" data-st="draft"><i class="bi bi-save me-1"></i>Keep as draft</button>
        <div class="small text-secondary">Current status: ${UI.badge(e.status)}</div></div></div></div>
      <div class="col-lg-8"><div class="card"><div class="card-header">Question paper preview <span class="small text-secondary">(answers shown in green – students don't see them)</span></div>
        <div class="card-body" style="max-height:72vh;overflow:auto">${r.questions.map((q, i) => `${i === 0 || q.section !== r.questions[i - 1].section ? (q.section ? `<h6 class="mt-2 text-primary">${esc(q.section)}</h6>` : "") : ""}
          <div class="mb-3 pb-3 border-bottom"><div class="d-flex gap-2"><b>Q${i + 1}.</b><div class="question-text flex-grow-1">${UI.safeHtml(q.text)}</div><span class="small text-secondary text-nowrap">+${UI.num(q.marks)}${e.negative_marking && Number(q.negative) ? ` / −${UI.num(q.negative)}` : ""}</span></div>
          ${q.media.map((m) => /image|equation/.test(m.type) ? `<img src="${esc(m.url)}" class="img-fluid rounded my-2" style="max-height:200px" alt="">` : "").join("")}
          ${q.options.length && q.type !== "true_false" ? `<div class="row g-1 small mt-1">${q.options.map((o) => `<div class="col-md-6 ${keys(q).includes(o.key) ? "text-success fw-bold" : ""}">${esc(o.key)}. ${UI.safeHtml(o.text)}</div>`).join("")}</div>`
            : `<div class="small text-success mt-1">Answer: ${esc(typeof q.correct_answer === "object" && q.correct_answer ? (q.correct_answer.value ?? [].concat(q.correct_answer).join(" / ")) : q.correct_answer ?? "graded manually")}</div>`}</div>`).join("") || UI.empty("No questions.", "patch-question")}</div></div></div></div>
      <div class="d-flex mt-3"><button class="btn btn-light" data-back><i class="bi bi-arrow-left me-1"></i>Back</button></div>`;
    pane.querySelector("[data-back]").onclick = () => go(5);
    pane.querySelectorAll("[data-st]").forEach((b) => (b.onclick = async () => {
      const st = b.dataset.st;
      if (st === "draft" && e.status === "draft") { UI.success("The exam is saved as a draft. You can come back and finish it any time.", "Saved"); return (location.href = "exams.html"); }
      if (st === "scheduled" && !e.start_time) return UI.warn("Set an opening time in step 1 to schedule the exam, or choose ‘Publish now’.", "Opening time needed");
      const msg = { live: "Assigned students will be able to start the exam right away.", scheduled: `The exam will open automatically at ${UI.fmtDateTime(e.start_time)}.`, draft: "Students will no longer see this exam." }[st];
      if (!(await UI.confirm(msg, { title: { live: "Publish now?", scheduled: "Schedule exam?", draft: "Move back to draft?" }[st], confirmText: "Yes, continue" }))) return;
      const res = await UI.run(() => API.call("exam.setStatus", { exam_id: examId, status: st }), { loading: "Saving…", quiet: true });
      if (res) { await UI.success(res.message, st === "live" ? "Published! 🎉" : "Done"); location.href = "exams.html"; }
    }));
  }

  const PANES = { 1: pane1, 2: pane2, 3: pane3, 4: pane4, 5: pane5, 6: pane6 };
  const startStep = Number(UI.qs("step")) || 1;
  go(examId ? startStep : 1);
});
