App.init({ roles: App.STAFF }).then((user) => {
  const TYPES = [
    { value: "mcq_single", label: "MCQ – single correct" }, { value: "mcq_multi", label: "MCQ – multiple correct" },
    { value: "true_false", label: "True / False" }, { value: "numerical", label: "Numerical" },
    { value: "short_answer", label: "Short answer (auto-checked)" }, { value: "long_answer", label: "Long answer (manual)" },
    { value: "coding", label: "Coding (manual)" }, { value: "file_upload", label: "File upload (manual)" },
  ];
  const typeLabel = (t) => (TYPES.find((x) => x.value === t) || { label: t }).label;
  const DIFF = [{ value: "easy", label: "Easy" }, { value: "medium", label: "Medium" }, { value: "hard", label: "Hard" }];
  const STATUS = ["draft", "under_review", "approved", "published", "rejected", "archived"].map((s) => ({ value: s, label: s.replace("_", " ").replace(/^\w/, (c) => c.toUpperCase()) }));
  const subjOpts = async () => {
    const [subs, cats] = await Promise.all([App.lookup("subjects"), App.lookup("exam_categories")]);
    return subs.map((s) => ({ value: s.id, label: `${s.name} (${cats.find((c) => c.id === s.exam_category_id)?.name || "—"})` }));
  };
  const chapOpts = async (v) => (v.subject_id ? App.options("chapters", { subject_id: v.subject_id }) : []);
  const topicOpts = async (v) => (v.chapter_id ? App.options("topics", { chapter_id: v.chapter_id }) : []);
  const L = (i) => String.fromCharCode(65 + i);

  // ---------- answer editor (options / correct answer) ----------
  const answerField = {
    name: "answer", label: "Answer", type: "html",
    render(container, values, form) {
      const state = { options: normOpts(values.options), correct: values.correct_answer };
      const typeSel = () => form.querySelector('[name="question_type"]')?.value || values.question_type || "mcq_single";
      const draw = () => {
        const t = typeSel();
        const keys = Array.isArray(state.correct) ? state.correct.map(String) : state.correct != null ? [String(state.correct)] : [];
        if (t === "mcq_single" || t === "mcq_multi" || t === "mcq_multiple") {
          if (state.options.length < 2) state.options = [0, 1, 2, 3].map((i) => state.options[i] || { key: L(i), text: "" });
          const multi = t !== "mcq_single";
          container.innerHTML = `<div class="small text-secondary mb-2">Type each option and tick the correct ${multi ? "ones" : "one"}.</div>` + state.options.map((o, i) => `
            <div class="input-group mb-2" data-opt="${i}"><span class="input-group-text"><input class="form-check-input mt-0" type="${multi ? "checkbox" : "radio"}" name="ans_correct" value="${UI.esc(o.key)}" ${keys.includes(o.key) ? "checked" : ""} title="Correct answer"></span>
            <span class="input-group-text fw-bold">${UI.esc(o.key)}</span><input class="form-control" data-text value="${UI.esc(o.text)}" placeholder="Option ${UI.esc(o.key)}">
            <button class="btn btn-outline-secondary" type="button" data-rm title="Remove option" ${state.options.length <= 2 ? "disabled" : ""}><i class="bi bi-x-lg"></i></button></div>`).join("") +
            `<button type="button" class="btn btn-sm btn-outline-primary" data-addopt ${state.options.length >= 8 ? "disabled" : ""}><i class="bi bi-plus"></i> Add option</button>`;
        } else if (t === "true_false") {
          const v = String(state.correct ?? "").toLowerCase();
          container.innerHTML = `<div class="btn-group" role="group">${["true", "false"].map((x) => `<input type="radio" class="btn-check" name="ans_tf" id="tf_${x}" value="${x}" ${v === x ? "checked" : ""}><label class="btn btn-outline-primary" for="tf_${x}">${x === "true" ? "True" : "False"}</label>`).join("")}</div>`;
        } else if (t === "numerical") {
          const c = state.correct && typeof state.correct === "object" ? state.correct : { value: state.correct ?? "", tolerance: 0 };
          container.innerHTML = `<div class="row g-2"><div class="col-6"><label class="form-label small">Correct value</label><input type="number" step="any" class="form-control" name="ans_value" value="${UI.esc(c.value ?? "")}"></div>
            <div class="col-6"><label class="form-label small">Allowed tolerance (±)</label><input type="number" step="any" min="0" class="form-control" name="ans_tol" value="${UI.esc(c.tolerance ?? 0)}"></div></div>`;
        } else if (t === "short_answer") {
          const list = Array.isArray(state.correct) ? state.correct.join(" | ") : state.correct ?? "";
          container.innerHTML = `<input class="form-control" name="ans_short" value="${UI.esc(list)}" placeholder="e.g. photosynthesis | photo-synthesis"><div class="form-text">Separate accepted answers with “|”. Matching ignores capital letters and extra spaces.</div>`;
        } else {
          container.innerHTML = `<div class="alert alert-light border small mb-0"><i class="bi bi-person-check me-1"></i>This type is graded manually by faculty after the exam. Use the explanation box for a model answer.</div>`;
        }
      };
      const sync = () => {
        const t = typeSel();
        if (container.querySelector("[data-opt]")) {
          state.options = [...container.querySelectorAll("[data-opt]")].map((r, i) => ({ key: L(i), text: r.querySelector("[data-text]").value }));
          const checked = [...container.querySelectorAll('[name="ans_correct"]:checked')].map((x) => x.value);
          state.correct = t === "mcq_single" ? checked[0] ?? null : checked;
        }
      };
      container.addEventListener("click", (e) => {
        if (e.target.closest("[data-addopt]")) { sync(); state.options.push({ key: L(state.options.length), text: "" }); draw(); }
        const rm = e.target.closest("[data-rm]");
        if (rm) { sync(); const i = Number(rm.closest("[data-opt]").dataset.opt); const removedKey = state.options[i].key; state.options.splice(i, 1);
          const remap = (k) => { const idx = k.charCodeAt(0) - 65; return idx > i ? L(idx - 1) : k; };
          if (Array.isArray(state.correct)) state.correct = state.correct.filter((k) => k !== removedKey).map(remap); else if (state.correct === removedKey) state.correct = null; else if (state.correct) state.correct = remap(state.correct);
          state.options = state.options.map((o, j) => ({ ...o, key: L(j) })); draw(); }
      });
      container.addEventListener("input", sync); container.addEventListener("change", sync);
      form.addEventListener("change", (e) => { if (e.target.name === "question_type") { sync(); state.correct = null; draw(); } });
      container._read = () => {
        sync(); const t = typeSel();
        if (t.startsWith("mcq")) return { options: state.options.filter((o) => o.text.trim()).map((o, i) => ({ key: L(i), text: o.text.trim() })), correct_answer: state.correct, _raw: state.options };
        if (t === "true_false") return { options: null, correct_answer: container.querySelector('[name="ans_tf"]:checked')?.value ?? null };
        if (t === "numerical") { const v = container.querySelector('[name="ans_value"]').value; return { options: null, correct_answer: v === "" ? null : { value: Number(v), tolerance: Number(container.querySelector('[name="ans_tol"]').value || 0) } }; }
        if (t === "short_answer") return { options: null, correct_answer: container.querySelector('[name="ans_short"]').value.split("|").map((s) => s.trim()).filter(Boolean) };
        return { options: null, correct_answer: null };
      };
      draw();
    },
    read: (form) => form.querySelector('[data-field="answer"] > div')?._read?.(),
    validate: (v, all) => {
      const t = all.question_type;
      if (!v) return "";
      if (t.startsWith("mcq")) {
        if (v._raw.some((o) => !o.text.trim())) return "Please fill in every option, or remove the empty ones.";
        if (v.options.length < 2) return "Add at least 2 options.";
        if (!v.correct_answer || (Array.isArray(v.correct_answer) && !v.correct_answer.length)) return "Please tick the correct option.";
      }
      if (t === "true_false" && !v.correct_answer) return "Please choose True or False.";
      if (t === "numerical" && (v.correct_answer === null || isNaN(v.correct_answer.value))) return "Please enter the correct value.";
      if (t === "short_answer" && !v.correct_answer.length) return "Please enter at least one accepted answer.";
      return "";
    },
  };
  function normOpts(o) {
    if (!o) return [];
    if (Array.isArray(o)) return o.map((x, i) => (typeof x === "string" ? { key: L(i), text: x } : { key: String(x.key ?? L(i)), text: String(x.text ?? x.value ?? "") }));
    if (typeof o === "object") return Object.entries(o).map(([k, v]) => ({ key: k, text: String(v) }));
    return [];
  }

  const fields = [
    { name: "question_text", label: "Question", type: "textarea", rows: 4, required: true, help: "Plain text, or simple HTML (&lt;b&gt;, &lt;sub&gt;, &lt;sup&gt;). Use “Insert image” for diagrams." },
    { name: "image_tools", type: "html", col: "col-12", render: (el, vals, form) => {
        el.innerHTML = `<div class="d-flex flex-wrap gap-2 align-items-center" style="margin-top:-.4rem">
          <button type="button" class="btn btn-outline-primary btn-sm" data-img><i class="bi bi-image me-1"></i>Insert image</button>
          <span class="small text-secondary">Diagrams, graphs or equations as images (JPG, PNG, GIF, WebP, SVG · max 10 MB). Stored in “question-images”.</span></div>`;
        el.querySelector("[data-img]").onclick = async () => {
          const file = await UI.pickFile("image/*"); if (!file) return;
          const up = await UI.upload(file, "question_image", {}, "Uploading image…"); if (!up) return;
          const ta = form.querySelector('[name="question_text"]');
          ta.value = `${ta.value}${ta.value && !ta.value.endsWith("\n") ? "\n" : ""}<img src="${up.url}" alt="diagram">`;
          ta.dispatchEvent(new Event("input", { bubbles: true }));
        };
      } },
    { name: "question_type", label: "Type", type: "select", required: true, options: TYPES, col: "col-md-4" },
    { name: "difficulty", label: "Difficulty", type: "select", options: DIFF, col: "col-md-4" },
    { name: "language", label: "Language", type: "select", options: [{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }], col: "col-md-4" },
    { name: "subject_id", label: "Subject", type: "select", options: subjOpts, col: "col-md-4" },
    { name: "chapter_id", label: "Chapter", type: "select", options: chapOpts, watch: ["subject_id"], col: "col-md-4" },
    { name: "topic_id", label: "Topic", type: "select", options: topicOpts, watch: ["subject_id", "chapter_id"], col: "col-md-4" },
    answerField,
    { name: "marks", label: "Marks", type: "number", min: 0.25, step: 0.25, required: true, col: "col-md-3" },
    { name: "negative_marks", label: "Negative marks", type: "number", min: 0, step: 0.25, col: "col-md-3" },
    { name: "status", label: "Status", type: "select", options: STATUS, col: "col-md-3" },
    { name: "tags", label: "Tags", placeholder: "comma, separated", col: "col-md-3" },
    { name: "explanation", label: "Explanation / model answer", type: "textarea", rows: 2 },
  ];

  const TICON = { mcq_single: "ui-radios", mcq_multi: "ui-checks", true_false: "toggle-on", numerical: "123", short_answer: "input-cursor-text", long_answer: "text-paragraph", coding: "code-slash", file_upload: "cloud-arrow-up" };
  function qCell(r) {
    const opts = normOpts(r.options);
    const keys = Array.isArray(r.correct_answer) ? r.correct_answer.map(String) : [String(r.correct_answer ?? "")];
    let ans = "";
    if (opts.length && /mcq/.test(r.question_type)) ans = `<div class="q-opts">${opts.slice(0, 6).map((o) => `<span class="${keys.includes(String(o.key)) ? "ok" : ""}"><b>${UI.esc(o.key)}</b>${UI.esc(UI.stripHtml(o.text)).slice(0, 40)}</span>`).join("")}</div>`;
    else if (r.question_type === "numerical" && r.correct_answer) ans = `<div class="q-opts"><span class="ok"><b>=</b>${UI.esc(r.correct_answer.value ?? r.correct_answer)}${Number(r.correct_answer.tolerance) ? ` ± ${UI.esc(r.correct_answer.tolerance)}` : ""}</span></div>`;
    else if (r.question_type === "true_false") ans = `<div class="q-opts"><span class="${keys[0] === "true" ? "ok" : ""}"><b>T</b>True</span><span class="${keys[0] === "false" ? "ok" : ""}"><b>F</b>False</span></div>`;
    return `<div class="q-cell"><span class="q-type" title="${UI.esc(typeLabel(r.question_type))}"><i class="bi bi-${TICON[r.question_type] || "patch-question"}"></i></span>
      <div class="min-w-0"><div class="q-text clamp-2">${UI.esc(UI.stripHtml(r.question_text))}</div>${ans}
      <div class="q-meta"><span>${UI.esc(typeLabel(r.question_type))}</span>${r.organization_id ? "" : '<span class="g">Shared</span>'}${r.source === "ai" ? '<span class="ai"><i class="bi bi-stars"></i> AI</span>' : r.source === "import" ? '<span><i class="bi bi-upload"></i> Imported</span>' : ""}</div></div></div>`;
  }

  const page = new CrudPage("#app", {
    table: "questions", title: "Question bank", icon: "patch-question", singular: "question", createLabel: "Add question", modalSize: "xl",
    columns: [
      { key: "question_text", label: "Question", class: "q-col", render: (r) => qCell(r) },
      { key: "subject.name", label: "Syllabus", render: (r) => r.subject ? `<div class="syl"><b>${UI.esc(r.subject.name)}</b>${r.chapter ? `<span><i class="bi bi-chevron-right"></i>${UI.esc(r.chapter.name)}</span>` : ""}${r.topic ? `<span><i class="bi bi-chevron-right"></i>${UI.esc(r.topic.name)}</span>` : ""}</div>` : '<span class="small text-secondary">Not linked</span>' },
      { key: "difficulty", label: "Level", render: (r) => (r.difficulty ? `<span class="lvl lvl-${r.difficulty}">${UI.esc(r.difficulty)}</span>` : "—") },
      { key: "marks", label: "Marks", render: (r) => `<span class="marks-pill">+${UI.num(r.marks)}${Number(r.negative_marks) ? ` <em>−${UI.num(r.negative_marks)}</em>` : ""}</span>` },
      { key: "status", label: "Status", render: (r) => UI.badge(r.status) },
    ],
    filters: [
      { name: "subject_id", label: "Subject", options: subjOpts },
      { name: "question_type", label: "Type", options: TYPES },
      { name: "difficulty", label: "Level", options: DIFF },
      { name: "status", label: "Status", options: STATUS },
    ],
    canEdit: (r) => r.organization_id || user.role === "super_admin",
    canDelete: (r) => r.organization_id || user.role === "super_admin",
    nameOf: (r) => r.question_text,
    defaults: () => ({ question_type: "mcq_single", difficulty: "medium", marks: 1, negative_marks: 0, status: "draft", language: "en" }),
    fields,
    toForm: (r) => ({ ...r, tags: (r.tags || []).join(", ") }),
    toSave: (v) => { const d = { ...v, ...(v.answer || {}) }; delete d.answer; delete d._raw; d.tags = v.tags ? v.tags.split(",").map((t) => t.trim()).filter(Boolean) : []; return d; },
    rowActions: [
      { icon: "eye", label: "Preview", onClick: (r) => preview(r) },
      { icon: "paperclip", label: "Images / audio / video for this question", onClick: (r) => mediaManager(r) },
      { icon: "check2-circle", label: "Approve", class: "btn-light text-success", show: (r) => ["draft", "under_review"].includes(r.status), onClick: (r) => setStatus([r.id], "approved") },
    ],
    headerActions: [
      { label: "Approve drafts on this page", icon: "check2-all", class: "btn-outline-success", onClick: (p) => { const ids = p.rows.filter((r) => ["draft", "under_review"].includes(r.status)).map((r) => r.id); if (!ids.length) return UI.info("There are no draft questions on this page."); setStatus(ids, "approved"); } },
      { label: "Import questions", icon: "upload", class: "btn-outline-primary", onClick: () => importQuestions() },
      { label: "Generate with AI", icon: "stars", class: "btn-outline-primary", onClick: () => aiGenerate() },
    ],
  });

  // ---------- media attached to a question (question-media bucket) ----------
  async function mediaManager(q) {
    const m = UI.modal({ title: "Question media", size: "lg", body: `<div class="text-center py-4"><span class="spinner-border text-primary"></span></div>` });
    const load = async () => {
      let r; try { r = await API.call("question.media", { question_id: q.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      m.body.innerHTML = `<div class="small text-secondary mb-2 clamp-2">${UI.esc(UI.stripHtml(q.question_text))}</div>
        <div class="upload-box mb-3"><div class="d-flex flex-wrap gap-2 align-items-center">
          <select class="form-select form-select-sm w-auto" data-type><option value="image">Image</option><option value="equation">Equation image</option><option value="audio">Audio</option><option value="video">Video</option><option value="file">PDF / file</option></select>
          <button class="btn btn-primary btn-sm" data-up><i class="bi bi-cloud-arrow-up me-1"></i>Upload media</button>
          <span class="small text-secondary">Shown to students under the question · max 10 MB</span></div></div>
        <div class="row g-3">${r.rows.length ? r.rows.map((x) => `<div class="col-md-4"><div class="card h-100"><div class="card-body p-2 text-center">
          ${/image|equation/.test(x.media_type) ? `<img src="${UI.esc(x.file_path)}" class="img-fluid rounded" style="max-height:140px" alt="">`
            : x.media_type === "audio" ? `<audio controls src="${UI.esc(x.file_path)}" class="w-100"></audio>`
            : x.media_type === "video" ? `<video controls src="${UI.esc(x.file_path)}" class="w-100 rounded"></video>`
            : `<a href="${UI.esc(x.file_path)}" target="_blank" rel="noopener"><i class="bi bi-file-earmark-pdf fs-1"></i></a>`}
          <div class="d-flex justify-content-between align-items-center mt-2"><span class="badge text-bg-light text-capitalize">${UI.esc(x.media_type)}</span>
          <button class="btn btn-sm btn-light text-danger" data-rm="${x.id}"><i class="bi bi-trash"></i></button></div></div></div></div>`).join("")
          : `<div class="col-12">${UI.empty("No media yet.", "image")}</div>`}</div>`;
      m.body.querySelector("[data-up]").onclick = async () => {
        const type = m.body.querySelector("[data-type]").value;
        const accept = { image: "image/*", equation: "image/*", audio: "audio/*", video: "video/*", file: ".pdf" }[type];
        const file = await UI.pickFile(accept); if (!file) return;
        const up = await UI.upload(file, "question_media", {}, "Uploading media…"); if (!up) return;
        if (await UI.run(() => API.call("question.addMedia", { question_id: q.id, media_type: type, file_path: up.url }))) load();
      };
      m.body.querySelectorAll("[data-rm]").forEach((b) => (b.onclick = async () => {
        if (!(await UI.confirm("Remove this media from the question?", { confirmText: "Remove", danger: true }))) return;
        if (await UI.run(() => API.call("question.removeMedia", { id: b.dataset.rm }))) load();
      }));
    };
    load();
  }

  async function setStatus(ids, status) {
    if (await UI.run(() => API.call("questions.setStatus", { ids, status }))) page.reload();
  }

  function renderQuestion(q) {
    const opts = normOpts(q.options);
    const keys = Array.isArray(q.correct_answer) ? q.correct_answer.map(String) : [String(q.correct_answer ?? "")];
    let ans = "";
    if (opts.length && q.question_type !== "true_false") ans = opts.map((o) => `<div class="option-item ${keys.includes(o.key) ? "selected" : ""}"><span class="option-key">${UI.esc(o.key)}</span><div>${UI.safeHtml(o.text)}</div>${keys.includes(o.key) ? '<i class="bi bi-check-circle-fill text-success ms-auto"></i>' : ""}</div>`).join("");
    else if (q.question_type === "true_false") ans = `<p>Correct answer: <strong class="text-capitalize">${UI.esc(q.correct_answer)}</strong></p>`;
    else if (q.question_type === "numerical") ans = `<p>Correct value: <strong>${UI.esc(q.correct_answer?.value ?? q.correct_answer)}</strong>${q.correct_answer?.tolerance ? ` (± ${UI.esc(q.correct_answer.tolerance)})` : ""}</p>`;
    else if (q.question_type === "short_answer") ans = `<p>Accepted answers: <strong>${UI.esc((q.correct_answer || []).join(" / "))}</strong></p>`;
    else ans = `<p class="text-secondary">Graded manually.</p>`;
    return `<div class="question-text mb-3">${UI.safeHtml(q.question_text)}</div>${ans}${q.explanation ? `<div class="alert alert-light border small mt-3"><strong>Explanation:</strong> ${UI.esc(q.explanation)}</div>` : ""}`;
  }
  function preview(q) { UI.modal({ title: "Question preview", size: "lg", body: renderQuestion(q) }); }

  async function aiGenerate() {
    const v = await UI.formModal({
      title: "Generate questions with AI", submitText: "Generate",
      fields: [
        { name: "subject_id", label: "Subject", type: "select", options: subjOpts, col: "col-md-4" },
        { name: "chapter_id", label: "Chapter", type: "select", options: chapOpts, watch: ["subject_id"], col: "col-md-4" },
        { name: "topic_id", label: "Topic", type: "select", options: topicOpts, watch: ["subject_id", "chapter_id"], col: "col-md-4" },
        { name: "topic_text", label: "Or describe the topic", placeholder: "e.g. Newton's laws of motion for class 11", col: "col-12" },
        { name: "doc", label: "Or upload study material (PDF, Word, text)", type: "html", col: "col-12",
          render: (c) => { c.innerHTML = `<input type="file" class="form-control" accept=".pdf,.docx,.txt"><div class="form-text">The AI writes questions only from this document. Scanned images can't be read.</div>`; },
          read: (form) => form.querySelector('[data-field="doc"] input')?.files[0] || null },
        { name: "question_type", label: "Question type", type: "select", required: true, options: TYPES.filter((t) => !["coding", "file_upload"].includes(t.value)), default: "mcq_single", col: "col-md-4" },
        { name: "difficulty", label: "Difficulty", type: "select", required: true, options: DIFF, default: "medium", col: "col-md-4" },
        { name: "count", label: "How many (1–20)", type: "number", min: 1, max: 20, step: 1, required: true, default: 5, col: "col-md-4" },
        { name: "language", label: "Language", type: "select", options: [{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }], default: "en", col: "col-md-4" },
        { name: "marks", label: "Marks each", type: "number", min: 0.25, step: 0.25, default: 1, col: "col-md-4" },
        { name: "negative_marks", label: "Negative marks", type: "number", min: 0, step: 0.25, default: 0, col: "col-md-4" },
        { name: "instructions", label: "Extra instructions (optional)", type: "textarea", rows: 2, placeholder: "e.g. include numerical calculations, avoid trick questions" },
      ],
      onSubmit: (vals) => { if (!vals.subject_id && !vals.chapter_id && !vals.topic_id && !vals.topic_text && !vals.doc) throw new API.ApiError("Please choose a subject/chapter, describe the topic, or upload a document."); return vals; },
    });
    if (!v) return;
    if (v.doc) { const t = await UI.run(() => Docs.text(v.doc), { loading: "Reading document…", success: false }); if (!t) return; v.source_text = t; }
    delete v.doc;
    const r = await UI.run(() => API.call("ai.generateQuestions", v), { loading: `AI is writing ${v.count} question${v.count > 1 ? "s" : ""}… this can take up to a minute`, quiet: true });
    if (!r) return;
    const m = UI.modal({
      title: `Review ${r.questions.length} AI questions`, size: "xl",
      body: `<div class="alert alert-warning small"><i class="bi bi-exclamation-triangle me-1"></i>AI can make mistakes. Check every question and answer before saving. Saved questions start as <b>draft</b>.</div>
        <div class="form-check mb-3"><input class="form-check-input" type="checkbox" id="aiAll" checked><label class="form-check-label" for="aiAll">Select all</label></div>
        ${r.questions.map((q, i) => `<div class="card mb-3 border"><div class="card-body"><div class="form-check mb-2"><input class="form-check-input" type="checkbox" data-q="${i}" checked id="aiq${i}"><label class="form-check-label fw-semibold" for="aiq${i}">Question ${i + 1}</label> ${UI.badge(q.difficulty)}</div>${renderQuestion(q)}</div></div>`).join("")}`,
      footer: `<button class="btn btn-light" data-bs-dismiss="modal">Discard</button><button class="btn btn-primary" data-save><i class="bi bi-save me-1"></i>Save selected</button>`,
    });
    m.el.querySelector("#aiAll").addEventListener("change", (e) => m.el.querySelectorAll("[data-q]").forEach((c) => (c.checked = e.target.checked)));
    m.el.querySelector("[data-save]").addEventListener("click", async () => {
      const items = [...m.el.querySelectorAll("[data-q]:checked")].map((c) => ({ ...r.questions[Number(c.dataset.q)], marks: v.marks || 1, negative_marks: v.negative_marks || 0, language: v.language, source: "ai" }));
      if (!items.length) return UI.warn("Please select at least one question to save.");
      const res = await UI.run(() => API.call("questions.bulkCreate", { items, subject_id: v.subject_id || null, chapter_id: v.chapter_id || null, topic_id: v.topic_id || null }), { loading: "Saving…", quiet: true });
      if (res) { m.close(); UI.success(res.message); page.reload(); }
    });
  }

  window.QuestionUI = { renderQuestion, normOpts, typeLabel };

  // ---------- summary tiles (click = filter the list) ----------
  (async () => {
    let t; try { t = await API.call("questions.summary"); } catch { return; }
    const head = document.querySelector("#app .page-head"); if (!head) return;
    head.insertAdjacentHTML("afterend", `<div class="row g-3 mb-3" id="qTiles">${[
      ["k1", "collection", "All questions", t.total, ""], ["k3", "patch-check", "Approved", t.approved, "status=approved"], ["k4", "hourglass-split", "Waiting for review", t.review, "status=draft"],
      ["k2", "emoji-smile", "Easy", t.easy, "difficulty=easy"], ["k5", "emoji-neutral", "Medium", t.medium, "difficulty=medium"], ["k6", "fire", "Hard", t.hard, "difficulty=hard"]]
      .map(([k, i, l, v, f]) => `<div class="col-6 col-md-4 col-xl-2"><div class="kpi ${k} cursor-pointer" data-qf="${f}"><div class="kpi-icon"><i class="bi bi-${i}"></i></div><div class="kpi-val">${v}</div><div class="kpi-lbl">${l}</div></div></div>`).join("")}</div>`);
    document.querySelectorAll("[data-qf]").forEach((c) => (c.onclick = () => {
      document.querySelectorAll("#app [data-fname]").forEach((x) => { x.value = ""; x.closest(".tb-select").classList.remove("on"); page.filters[x.dataset.fname] = ""; });
      if (c.dataset.qf) { const [k, v] = c.dataset.qf.split("="); const sel = document.querySelector(`#app [data-fname="${k}"]`); if (sel) { sel.value = v; sel.closest(".tb-select").classList.add("on"); page.filters[k] = v; } }
      page.page = 1; page.reload(); page.syncReset();
    }));
  })();

  // ---------- import questions from Excel / CSV ----------
  const QCOLS = ["question_text", "question_type", "option_a", "option_b", "option_c", "option_d", "option_e", "correct", "explanation", "exam_category", "subject", "chapter", "topic", "difficulty", "marks", "negative_marks", "tags"];
  const QSAMPLE = [
    ["A body starts from rest with acceleration 2 m/s². What is its velocity after 5 s?", "mcq_single", "5 m/s", "10 m/s", "20 m/s", "2.5 m/s", "", "B", "v = u + at = 0 + 2 × 5 = 10 m/s", "JEE Main", "Physics", "Kinematics", "Motion in a Straight Line", "easy", "4", "1", "kinematics"],
    ["Which of these are vector quantities?", "mcq_multi", "Velocity", "Speed", "Force", "Mass", "", "A,C", "Velocity and force have direction.", "JEE Main", "Physics", "", "", "medium", "4", "0", ""],
    ["How many moles are in 36 g of water (H₂O)?", "numerical", "", "", "", "", "", "2", "36 ÷ 18 = 2 mol", "JEE Main", "Chemistry", "", "", "easy", "4", "0", ""],
    ["Mature human red blood cells have no nucleus.", "true_false", "", "", "", "", "", "True", "", "NEET UG", "Biology", "", "", "easy", "4", "0", ""]];
  const QALIAS = { question: "question_text", "question text": "question_text", type: "question_type", "question type": "question_type", a: "option_a", b: "option_b", c: "option_c", d: "option_d", e: "option_e",
    "option a": "option_a", "option b": "option_b", "option c": "option_c", "option d": "option_d", "option e": "option_e", answer: "correct", "correct answer": "correct", "correct option": "correct",
    exam: "exam_category", "exam type": "exam_category", level: "difficulty", "negative marks": "negative_marks", negative: "negative_marks" };
  const qnorm = (h) => { const k = String(h || "").trim().toLowerCase().replace(/[_.]+/g, " ").replace(/\s+/g, " "); const u = k.replace(/ /g, "_"); return QCOLS.includes(u) ? u : QALIAS[k] || u; };

  async function importQuestions() {
    let rows = [];
    const m = UI.modal({ title: "Import questions", size: "xl", body: "", footer: `<button class="btn btn-light" data-bs-dismiss="modal">Close</button>` });
    const step1 = () => {
      m.body.innerHTML = `<div class="import-steps mb-3"><span class="on">1 · File</span><span>2 · Check</span><span>3 · Result</span></div>
        <div class="row g-3"><div class="col-lg-5"><div class="import-help h-100">
          <h6 class="fw-bold"><i class="bi bi-file-earmark-spreadsheet me-1"></i>Get the template</h6>
          <p class="small text-secondary mb-2">One row per question. <b>question_type</b>: mcq_single, mcq_multi, numerical, true_false, short_answer or long_answer.
            <b>correct</b>: the option letter (B), letters for multiple (A,C), the number for numerical, True/False, or the accepted answer.</p>
          <p class="small text-secondary mb-2"><b>subject / chapter / topic</b> must match names on the Syllabus page (exam_category is optional).</p>
          <div class="d-flex gap-2 flex-wrap"><button class="btn btn-sm btn-success" data-tpl="xlsx"><i class="bi bi-file-earmark-excel me-1"></i>Excel template</button>
            <button class="btn btn-sm btn-outline-secondary" data-tpl="csv"><i class="bi bi-filetype-csv me-1"></i>CSV template</button></div></div></div>
          <div class="col-lg-7"><label class="form-label">Save imported questions as</label>
            <div class="seg mb-3" id="qSt"><button class="on" data-st="draft">Draft (review first)</button><button data-st="approved">Approved (ready for exams)</button></div>
            <label class="upload-drop" id="qDrop"><input type="file" accept=".xlsx,.xls,.csv" hidden id="qFile"><i class="bi bi-cloud-arrow-up"></i><b>Choose the Excel or CSV file</b><span class="small text-secondary">or drag & drop it here · up to 1000 questions</span></label></div></div>`;
      m.body.querySelectorAll("#qSt button").forEach((b) => (b.onclick = () => m.body.querySelectorAll("#qSt button").forEach((x) => x.classList.toggle("on", x === b))));
      m.body.querySelectorAll("[data-tpl]").forEach((b) => (b.onclick = () => (b.dataset.tpl === "csv" ? Exporter.csv("Question import template", QCOLS, QSAMPLE) : UI.run(() => Exporter.xlsx("Question import template", QCOLS, QSAMPLE), { loading: "Preparing…", success: false }))));
      const take = async (file) => {
        if (!file) return;
        let raw; try { UI.loading(true, "Reading the file…"); raw = await Exporter.readRows(file); } catch (e) { return UI.handle(e); } finally { UI.loading(false); }
        rows = raw.map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k === "_line" ? k : qnorm(k), v]))).filter((r) => r.question_text);
        if (!rows.length) return UI.warn("No questions were found. Make sure the first row has the column names (question_text, option_a, …).");
        if (rows.length > 1000) return UI.warn("Please import at most 1000 questions at a time.");
        step2(m.body.querySelector("#qSt .on").dataset.st);
      };
      const fi = m.body.querySelector("#qFile"), drop = m.body.querySelector("#qDrop");
      fi.onchange = () => take(fi.files[0]);
      drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
      drop.addEventListener("dragleave", () => drop.classList.remove("over"));
      drop.addEventListener("drop", (e) => { e.preventDefault(); drop.classList.remove("over"); take(e.dataTransfer.files[0]); });
    };
    const step2 = (status) => {
      m.body.innerHTML = `<div class="import-steps mb-3"><span class="done">1 · File</span><span class="on">2 · Check</span><span>3 · Result</span></div>
        <div class="d-flex gap-2 align-items-center mb-2"><span class="chip chip-published">${rows.length} questions</span><span class="chip">saved as ${status}</span><span class="small text-secondary ms-auto">First ${Math.min(50, rows.length)} shown</span></div>
        <div class="table-responsive border rounded-3" style="max-height:48vh"><table class="table table-sm mb-0"><thead><tr><th>Line</th><th>Question</th><th>Type</th><th>Options</th><th>Correct</th><th>Subject</th><th>Level</th></tr></thead>
        <tbody>${rows.slice(0, 50).map((r) => `<tr><td class="text-secondary">${r._line ?? ""}</td><td class="small" style="min-width:260px">${UI.esc(r.question_text)}</td><td class="small">${UI.esc(r.question_type || "mcq_single")}</td>
          <td class="small">${["a", "b", "c", "d", "e"].filter((k) => r["option_" + k]).map((k) => `<b>${k.toUpperCase()}</b> ${UI.esc(r["option_" + k])}`).join("<br>")}</td><td class="small fw-bold">${UI.esc(r.correct || "")}</td>
          <td class="small">${UI.esc(r.subject || "")}${r.chapter ? " › " + UI.esc(r.chapter) : ""}</td><td class="small">${UI.esc(r.difficulty || "medium")}</td></tr>`).join("")}</tbody></table></div>
        <div class="d-flex gap-2 mt-3"><button class="btn btn-light" id="qBack"><i class="bi bi-arrow-left me-1"></i>Choose another file</button><button class="btn btn-primary ms-auto" id="qGo"><i class="bi bi-upload me-1"></i>Import ${rows.length} questions</button></div>`;
      m.body.querySelector("#qBack").onclick = step1;
      m.body.querySelector("#qGo").onclick = async () => {
        const res = { saved: 0, failed: 0, rows: [] };
        try {
          for (let i = 0; i < rows.length; i += 50) {
            UI.loading(true, `Importing ${Math.min(i + 50, rows.length)} of ${rows.length}…`);
            const r = await API.call("questions.import", { status, rows: rows.slice(i, i + 50) });
            res.saved += r.saved; res.failed += r.failed; res.rows.push(...r.rows);
          }
        } catch (e) { UI.handle(e); } finally { UI.loading(false); }
        page.reload();
        m.body.innerHTML = `<div class="import-steps mb-3"><span class="done">1 · File</span><span class="done">2 · Check</span><span class="on">3 · Result</span></div>
          <div class="row g-3 mb-3"><div class="col-6"><div class="kpi k3"><div class="kpi-icon"><i class="bi bi-check2-circle"></i></div><div class="kpi-val">${res.saved}</div><div class="kpi-lbl">Imported (${status})</div></div></div>
          <div class="col-6"><div class="kpi k6"><div class="kpi-icon"><i class="bi bi-exclamation-triangle"></i></div><div class="kpi-val">${res.failed}</div><div class="kpi-lbl">Not imported</div></div></div></div>
          ${res.failed ? `<h6>Rows that need fixing</h6><div class="table-responsive border rounded-3" style="max-height:40vh"><table class="table table-sm mb-0"><thead><tr><th>Line</th><th>Question</th><th>Problem</th></tr></thead><tbody>
            ${res.rows.filter((x) => !x.ok).map((x) => `<tr class="table-danger"><td>${x.line}</td><td class="small">${UI.esc(x.question || "")}</td><td class="small text-danger">${UI.esc(x.message)}</td></tr>`).join("")}</tbody></table></div>` : '<div class="alert alert-success mb-0">All questions were imported.</div>'}
          <div class="d-flex mt-3"><button class="btn btn-light" id="qAgain"><i class="bi bi-upload me-1"></i>Import another file</button></div>`;
        m.body.querySelector("#qAgain").onclick = step1;
        if (res.saved) UI.toast(`${res.saved} question(s) imported.`);
      };
    };
    step1();
  }
});
