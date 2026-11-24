App.init({ roles: App.STAFF }).then(() => {
  const admin = App.isAdmin();
  const el = document.getElementById("app");
  const state = { cat: null, subject: null, unit: null, chapter: null, tree: { subjects: [], units: [], chapters: [], topics: [] }, cats: [] };

  el.innerHTML = `
    <div class="d-flex flex-wrap align-items-center gap-2 mb-3">
      <div><h1 class="page-title"><i class="bi bi-diagram-3 me-2 text-primary"></i>Syllabus</h1><div class="text-secondary small">Exam → subject → unit → chapter → topic</div></div>
      <div class="ms-auto d-flex gap-2">${admin ? `<button class="btn btn-outline-primary" id="aiImport"><i class="bi bi-cloud-upload me-1"></i>Import syllabus</button>` : ""}</div>
    </div>
    <div class="card mb-3"><div class="card-body d-flex flex-wrap gap-2 align-items-center">
      <label class="fw-semibold me-2">Exam category</label>
      <select class="form-select w-auto" style="min-width:240px" id="catSel"></select>
      ${admin ? `<button class="btn btn-light" id="catAdd" title="Add category"><i class="bi bi-plus-lg"></i> New</button>
      <button class="btn btn-light" id="catEdit" title="Edit category"><i class="bi bi-pencil"></i></button>
      <button class="btn btn-light text-danger" id="catDel" title="Delete category"><i class="bi bi-trash"></i></button>` : ""}
    </div></div>
    <div class="row g-3" id="cols"></div>`;

  const catSel = document.getElementById("catSel");
  const LEVELS = [
    { key: "subjects", table: "subjects", title: "Subjects", parent: "exam_category_id", parentOf: () => state.cat, sel: "subject" },
    { key: "units", table: "units", title: "Units", parent: "subject_id", parentOf: () => state.subject, sel: "unit" },
    { key: "chapters", table: "chapters", title: "Chapters", parent: "subject_id", parentOf: () => state.subject, sel: "chapter" },
    { key: "topics", table: "topics", title: "Topics", parent: "chapter_id", parentOf: () => state.chapter, sel: null },
  ];

  async function loadCats(selectId) {
    try {
      const r = await API.call("crud.list", { table: "exam_categories", pageSize: 500 });
      state.cats = r.rows;
    } catch (e) { return UI.handle(e); }
    catSel.innerHTML = state.cats.length ? state.cats.map((c) => `<option value="${c.id}">${UI.esc(c.name)}${c.is_active === false ? " (inactive)" : ""}</option>`).join("") : `<option value="">No categories yet</option>`;
    state.cat = selectId || state.cat || state.cats[0]?.id || null;
    if (state.cat && !state.cats.some((c) => c.id === state.cat)) state.cat = state.cats[0]?.id || null;
    catSel.value = state.cat || "";
    loadTree();
  }
  async function loadTree() {
    if (!state.cat) { document.getElementById("cols").innerHTML = `<div class="col-12"><div class="card">${UI.empty(admin ? "Create an exam category first (e.g. JEE, NEET, Semester 1)." : "No exam categories yet.", "diagram-3")}</div></div>`; return; }
    try { state.tree = await API.call("syllabus.tree", { exam_category_id: state.cat }); } catch (e) { return UI.handle(e); }
    if (!state.tree.subjects.some((s) => s.id === state.subject)) state.subject = state.tree.subjects[0]?.id || null;
    state.tree.units = state.tree.units || [];
    if (state.unit && !state.tree.units.some((x) => x.id === state.unit && x.subject_id === state.subject)) state.unit = null;
    const chs = chapterList();
    if (!chs.some((c) => c.id === state.chapter)) state.chapter = chs[0]?.id || null;
    render();
  }
  // chapters of the selected subject, narrowed to the selected unit (if any)
  const chapterList = () => state.tree.chapters.filter((c) => c.subject_id === state.subject && (!state.unit || c.unit_id === state.unit));
  const unitName = (id) => state.tree.units.find((x) => x.id === id)?.name;
  function render() {
    document.getElementById("cols").innerHTML = LEVELS.map((L) => {
      const pid = L.parentOf();
      const items = L.key === "chapters" ? chapterList() : state.tree[L.key].filter((x) => x[L.parent] === pid);
      const selected = L.sel ? state[L.sel] : null;
      return `<div class="col-md-6 col-xl-3 tree-col"><div class="card h-100">
        <div class="card-header d-flex align-items-center">${L.title} <span class="badge text-bg-light ms-2">${items.length}</span>
        ${admin && pid ? `<span class="ms-auto d-flex gap-1">${L.key === "chapters" && items.some((x) => x.status !== "published") ? `<button class="btn btn-sm btn-outline-success" data-approveall="1" title="Approve all chapters in review"><i class="bi bi-check2-all"></i></button>` : ""}<button class="btn btn-sm btn-primary" data-add="${L.key}"><i class="bi bi-plus-lg"></i> Add</button></span>` : ""}</div>
        <div class="list-group list-group-flush">${L.key === "units" && pid ? `<div class="list-group-item ${!state.unit ? "active" : ""}" data-allunits="1"><span class="fst-italic">All chapters of this subject</span></div>` : ""}
        ${!pid ? UI.empty(`Select a ${L.key === "topics" ? "chapter" : "subject"} first.`, "arrow-left") : items.length ? items.map((x) => `
          <div class="list-group-item ${x.id === selected ? "active" : ""}" data-pick="${L.key}" data-id="${x.id}">
            <div class="text-truncate"><span class="${x.is_active === false ? "text-decoration-line-through text-secondary" : ""}">${UI.esc(x.name)}</span>
            ${x.code ? `<span class="small text-secondary ms-1">${UI.esc(x.code)}</span>` : ""}
            ${x.weightage ? `<span class="badge text-bg-light ms-1">${UI.esc(x.weightage)}%</span>` : ""}
            ${L.key === "chapters" && !state.unit && x.unit_id ? `<div class="small text-secondary">${UI.esc(unitName(x.unit_id) || "")}</div>` : ""}
            ${x.status && x.status !== "published" ? UI.badge(x.status) : ""}</div>
            ${admin ? `<span class="item-actions">${L.key === "chapters" && x.status && x.status !== "published" ? `<button class="btn btn-sm btn-light text-success" data-approve="${x.id}" title="Approve & publish"><i class="bi bi-check2-circle"></i></button>` : ""}<button class="btn btn-sm btn-light" data-edit="${L.key}" data-id="${x.id}"><i class="bi bi-pencil"></i></button><button class="btn btn-sm btn-light text-danger" data-del="${L.key}" data-id="${x.id}"><i class="bi bi-trash"></i></button></span>` : ""}
          </div>`).join("") : UI.empty(L.key === "units" ? "No units – optional. Use units to group chapters (e.g. Mechanics)." : `No ${L.key} yet.`, "inbox")}</div></div></div>`;
    }).join("");
  }

  document.getElementById("cols").addEventListener("click", (e) => {
    if (e.target.closest("[data-allunits]")) { state.unit = null; state.chapter = chapterList()[0]?.id || null; return render(); }
    const t = e.target.closest("[data-add],[data-edit],[data-del],[data-pick]");
    if (!t) return;
    const L = LEVELS.find((l) => l.key === (t.dataset.add || t.dataset.edit || t.dataset.del || t.dataset.pick));
    if (t.dataset.add) return editItem(L, null);
    const item = state.tree[L.key].find((x) => x.id === t.dataset.id);
    if (t.dataset.edit) { e.stopPropagation(); return editItem(L, item); }
    if (t.dataset.del) { e.stopPropagation(); return delItem(L, item); }
    if (L.sel) {
      state[L.sel] = item.id;
      if (L.key === "subjects") { state.unit = null; state.chapter = chapterList()[0]?.id || null; }
      if (L.key === "units") state.chapter = chapterList()[0]?.id || null;
      render();
    }
  });

  function fieldsFor(L) {
    const f = [{ name: "name", label: "Name", required: true, col: "col-md-8" }, { name: "code", label: "Code", col: "col-md-4" }, { name: "order_index", label: "Order", type: "number", min: 0, step: 1, col: "col-md-4" }];
    if (L.key === "chapters") f.push({ name: "unit_id", label: "Unit", type: "select", col: "col-md-8", placeholder: "— No unit —",
      options: state.tree.units.filter((x) => x.subject_id === state.subject).map((x) => ({ value: x.id, label: x.name })) });
    if (L.key === "chapters") f.push({ name: "weightage", label: "Weightage (%)", type: "number", min: 0, max: 100, col: "col-md-4" }, { name: "status", label: "Status", type: "select", col: "col-md-4", options: [{ value: "published", label: "Published" }, { value: "draft", label: "Draft" }, { value: "in_review", label: "In review" }] });
    f.push({ name: "is_active", label: "Active", type: "checkbox", col: "col-md-4" });
    return f;
  }
  async function editItem(L, item) {
    const pid = L.parentOf();
    const siblings = state.tree[L.key].filter((x) => x[L.parent] === pid);
    await UI.formModal({
      title: `${item ? "Edit" : "Add"} ${L.title.slice(0, -1).toLowerCase()}`, size: "", fields: fieldsFor(L),
      values: item || { is_active: true, order_index: siblings.length, status: "published", unit_id: state.unit || "" },
      onSubmit: async (v) => {
        const data = { ...v, [L.parent]: item ? item[L.parent] : pid };
        if (L.key === "chapters") data.unit_id = v.unit_id || null;
        const r = await API.call("crud.save", { table: L.table, id: item?.id, data });
        UI.toast(r.message);
        if (L.sel && !item) state[L.sel] = r.row.id;
        App.clearLookup(); loadTree();
      },
    });
  }
  async function delItem(L, item) {
    const msg = L.key === "units" ? "Its chapters stay in the subject (without a unit)." : L.key === "subjects" ? "Its units, chapters and topics must be deleted first." : L.key === "chapters" ? "Its topics must be deleted first." : "Questions linked to this topic will keep their subject and chapter.";
    if (!(await UI.confirm(`"${item.name}" will be deleted. ${msg}`, { title: "Delete?", confirmText: "Delete", danger: true }))) return;
    if (await UI.run(() => API.call("crud.delete", { table: L.table, id: item.id }), { loading: "Deleting…" })) { App.clearLookup(); loadTree(); }
  }

  catSel.addEventListener("change", () => { state.cat = catSel.value; state.subject = state.chapter = null; loadTree(); });
  const catFields = [
    { name: "name", label: "Name", required: true, placeholder: "e.g. JEE Main" }, { name: "code", label: "Code", placeholder: "JEE" },
    { name: "description", label: "Description", type: "textarea", rows: 2 },
    { name: "color", label: "Colour", type: "color", col: "col-md-4" }, { name: "icon", label: "Bootstrap icon name", col: "col-md-4", placeholder: "journal-bookmark" },
    { name: "is_active", label: "Active", type: "checkbox", col: "col-md-4" },
  ];
  const saveCat = (row) => UI.formModal({
    title: row ? "Edit exam category" : "New exam category", fields: catFields, values: row || { is_active: true, color: "#115e59", icon: "journal-bookmark" },
    onSubmit: async (v) => { const r = await API.call("crud.save", { table: "exam_categories", id: row?.id, data: v }); UI.toast(r.message); App.clearLookup(); loadCats(r.row.id); },
  });
  if (admin) {
    document.getElementById("catAdd").onclick = () => saveCat(null);
    document.getElementById("catEdit").onclick = () => { const c = state.cats.find((x) => x.id === state.cat); if (!c) return UI.warn("Please select a category first."); saveCat(c); };
    document.getElementById("catDel").onclick = async () => {
      const c = state.cats.find((x) => x.id === state.cat); if (!c) return UI.warn("Please select a category first.");
      if (!(await UI.confirm(`"${c.name}" will be deleted. Its subjects must be removed first.`, { title: "Delete category?", confirmText: "Delete", danger: true }))) return;
      if (await UI.run(() => API.call("crud.delete", { table: "exam_categories", id: c.id }))) { state.cat = null; App.clearLookup(); loadCats(); }
    };
    document.getElementById("aiImport").onclick = aiImport;
  }

  async function aiImport() {
    if (!state.cat) return UI.warn("Please create or select an exam category first.");
    const catName = state.cats.find((c) => c.id === state.cat)?.name;
    const v = await UI.formModal({
      title: `Import syllabus → ${catName}`, submitText: "Continue",
      fields: [
        { name: "mode", label: "Source", type: "select", required: true, col: "col-12", default: "sheet", options: [
          { value: "sheet", label: "Excel / CSV file (columns: subject, unit, chapter, topic, weightage)" },
          { value: "doc", label: "PDF / Word / text file – AI extracts the structure" },
          { value: "text", label: "Paste text – AI extracts the structure" }] },
        { name: "file", label: "File", type: "html", col: "col-12", visible: (x) => x.mode !== "text",
          render: (c) => { c.innerHTML = `<input type="file" class="form-control" accept=".xlsx,.xls,.csv,.pdf,.docx,.txt">`; },
          read: (form) => form.querySelector('[data-field="file"] input')?.files[0] || null,
          validate: (f, all) => (all.mode !== "text" && !f ? "Please choose a file." : "") },
        { name: "text", label: "Syllabus text", type: "textarea", rows: 10, visible: (x) => x.mode === "text", validate: (t, all) => (all.mode === "text" && (!t || t.length < 20) ? "Please paste the syllabus text." : "") },
      ],
    });
    if (!v) return;
    let subjects;
    if (v.mode === "sheet") {
      const rows = await UI.run(() => Docs.rows(v.file), { loading: "Reading spreadsheet…", success: false });
      if (!rows) return;
      const map = new Map();
      rows.forEach((r) => {
        const sn = r.subject || r.subject_name; if (!sn) return;
        if (!map.has(sn)) map.set(sn, new Map());
        const cn = r.chapter || r.chapter_name; if (!cn) return;
        const chs = map.get(sn); if (!chs.has(cn)) chs.set(cn, { name: cn, unit: r.unit || r.unit_name || null, weightage: r.weightage || null, topics: [] });
        const tn = r.topic || r.topic_name; if (tn) chs.get(cn).topics.push(tn);
      });
      subjects = [...map].map(([name, chs]) => ({ name, chapters: [...chs.values()] }));
      if (!subjects.length) return UI.warn("No rows with a “subject” column were found. The first row must be the header: subject, chapter, topic, weightage.");
    } else {
      let text = v.text;
      if (v.mode === "doc") { text = await UI.run(() => Docs.text(v.file), { loading: "Reading document…", success: false }); if (!text) return; }
      const r = await UI.run(() => API.call("ai.parseSyllabus", { text }), { loading: "AI is reading the syllabus…", quiet: true });
      if (!r) return;
      subjects = r.subjects;
    }
    // AI may group chapters in units: flatten to chapters that remember their unit name
    subjects = subjects.map((sb) => ({ name: sb.name, chapters: [...(sb.chapters || []), ...(sb.units || []).flatMap((un) => (un.chapters || []).map((c) => ({ ...c, unit: un.name })))] }));
    // keep the original file in the "syllabus-files" bucket for the record
    let fileRef = null;
    if (v.file) { const up = await UI.run(() => API.upload(v.file, "syllabus"), { loading: "Saving the syllabus file…", success: false }); if (!up) return; fileRef = up.path; }
    const counts = subjects.reduce((a, s) => { a.c += (s.chapters || []).length; a.t += (s.chapters || []).reduce((n, c) => n + (c.topics || []).length, 0); return a; }, { c: 0, t: 0 });
    const preview = subjects.map((s) => `<li><strong>${UI.esc(s.name)}</strong><ul>${(s.chapters || []).map((c) => `<li>${c.unit ? `<span class="badge text-bg-light me-1">${UI.esc(c.unit)}</span>` : ""}${UI.esc(c.name)}${(c.topics || []).length ? `<div class="small text-secondary">${(c.topics || []).map((t) => UI.esc(typeof t === "string" ? t : t.name)).join(", ")}</div>` : ""}</li>`).join("")}</ul></li>`).join("");
    const m = UI.modal({ title: "Review before importing", size: "lg", body: `<div class="alert alert-info small">Found ${subjects.length} subjects, ${counts.c} chapters and ${counts.t} topics. Items with the same name are not duplicated. New chapters are added as <b>In review</b> – approve them on this page.</div><ul>${preview}</ul>`,
      footer: `<button class="btn btn-light" data-bs-dismiss="modal">Cancel</button><button class="btn btn-primary" data-go><i class="bi bi-check2 me-1"></i>Import all</button>` });
    m.el.querySelector("[data-go]").onclick = async () => {
      const res = await UI.run(() => API.call("syllabus.import", { exam_category_id: state.cat, subjects, source: v.mode, file_url: fileRef }), { loading: "Importing…", quiet: true });
      if (res) { m.close(); UI.success(res.message); App.clearLookup(); loadTree(); }
    };
  }

  async function setChapterStatus(ids, status) {
    if (await UI.run(() => API.call("syllabus.setStatus", { chapter_ids: ids, status }))) loadTree();
  }
  document.getElementById("cols").addEventListener("click", (e) => {
    const all = e.target.closest("[data-approveall]");
    if (all) { e.stopPropagation(); return setChapterStatus(state.tree.chapters.filter((c) => c.subject_id === state.subject && c.status !== "published").map((c) => c.id), "published"); }
    const b = e.target.closest("[data-approve]"); if (!b) return; e.stopPropagation(); setChapterStatus([b.dataset.approve], "published");
  }, true);

  loadCats();
});
