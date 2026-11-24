/* Student exam screen: timer, palette, auto-save, tab-switch tracking, auto-submit */
App.init({ roles: ["student"], bare: true }).then(async () => {
  const el = document.getElementById("app");
  const examId = UI.qs("id");
  let d;
  try { d = await API.call("student.startExam", { exam_id: examId }); }
  catch (e) { await UI.handle(e); location.replace("my-exams.html"); return; }

  const Q = d.questions;
  const answers = { ...(d.attempt.answers || {}) };
  const flagged = new Set(d.attempt.flagged || []);
  let tabSwitches = d.attempt.tab_switches || 0;
  let idx = 0, remaining = d.remaining_seconds, dirty = false, submitting = false, submitted = false;
  // seconds spent on each question (only counted while this tab is visible)
  const qtime = { ...(d.attempt.qtime || {}) };
  const visited = new Set([...Object.keys(d.attempt.answers || {}), ...(d.attempt.flagged || []), ...Object.keys(d.attempt.qtime || {})]);
  setInterval(() => {
    if (submitted || document.hidden || !Q[idx]) return;
    const id = Q[idx].id; qtime[id] = (qtime[id] || 0) + 1; dirty = true;
    const el = document.getElementById("qTimer"); if (el) el.textContent = UI.duration(qtime[id]);
  }, 1000);
  const backupKey = `ep_attempt_${d.attempt.id}`;
  try { const b = JSON.parse(localStorage.getItem(backupKey) || "null"); if (b && b.answers) Object.assign(answers, b.answers); } catch { /* ignore */ }

  document.title = d.exam.title;
  el.className = "";
  el.innerHTML = `
    <div class="exam-header"><div class="container-fluid py-2 d-flex align-items-center gap-3">
      <div class="fw-bold text-truncate flex-grow-1">${UI.esc(d.exam.title)}</div>
      <span class="small text-secondary d-none d-md-inline" id="saveState"><i class="bi bi-cloud-check"></i> Saved</span>
      <span class="timer" id="timer">--:--</span>
      <button class="btn btn-success" id="submitBtn"><i class="bi bi-send me-1"></i>Submit</button>
    </div></div>
    <div class="container-fluid py-3 no-select"><div class="row g-3">
      <div class="col-lg-9"><div class="card"><div class="card-body p-4" id="qBox"></div>
        <div class="card-footer bg-white d-flex flex-wrap gap-2">
          <button class="btn btn-outline-secondary" id="prevBtn"><i class="bi bi-chevron-left"></i> Previous</button>
          <button class="btn btn-outline-warning" id="flagBtn"><i class="bi bi-flag"></i> Mark for review</button>
          <button class="btn btn-outline-danger" id="clearBtn"><i class="bi bi-eraser"></i> Clear answer</button>
          <button class="btn btn-primary ms-auto" id="nextBtn">Save & next <i class="bi bi-chevron-right"></i></button>
        </div></div></div>
      <div class="col-lg-3"><div class="card"><div class="card-body">
        <div class="fw-semibold mb-2">Questions</div><div class="q-palette" id="palette"></div>
        <div class="small text-secondary mt-3 d-flex flex-wrap gap-3">
          <span><span class="legend-dot" style="background:#fff;border:1px solid #CBD5E1"></span>Not visited</span>
          <span><span class="legend-dot" style="background:#DC2626"></span>Not answered</span>
          <span><span class="legend-dot" style="background:#16A34A"></span>Answered</span>
          <span><span class="legend-dot" style="background:#EA580C"></span>Marked for review</span>
          <span><span class="legend-dot" style="background:#16A34A;box-shadow:inset -4px -4px 0 #EA580C"></span>Answered &amp; marked</span></div>
        <hr><div class="small" id="summary"></div>
        ${d.exam.instructions ? `<hr><button class="btn btn-sm btn-light w-100" id="instrBtn"><i class="bi bi-info-circle me-1"></i>Instructions</button>` : ""}
      </div></div></div>
    </div></div>`;

  const isAnswered = (q) => { const a = answers[q.id]; return !(a === undefined || a === null || a === "" || (Array.isArray(a) && !a.length)); };

  function renderQ() {
    const q = Q[idx];
    let input = "";
    const a = answers[q.id];
    if (q.type === "mcq_single" || q.type === "true_false") {
      input = q.options.map((o) => `<div class="option-item ${String(a) === o.key ? "selected" : ""}" data-key="${UI.esc(o.key)}"><span class="option-key">${q.type === "true_false" ? (o.key === "true" ? "T" : "F") : UI.esc(o.key)}</span><div>${UI.safeHtml(o.text)}</div></div>`).join("");
    } else if (q.type === "mcq_multi" || q.type === "mcq_multiple") {
      const sel = Array.isArray(a) ? a : [];
      input = `<div class="small text-secondary mb-2">Select all correct options.</div>` + q.options.map((o) => `<div class="option-item ${sel.includes(o.key) ? "selected" : ""}" data-key="${UI.esc(o.key)}" data-multi="1"><span class="option-key">${UI.esc(o.key)}</span><div>${UI.safeHtml(o.text)}</div></div>`).join("");
    } else if (q.type === "numerical") {
      input = `<input type="number" step="any" class="form-control form-control-lg" style="max-width:300px" placeholder="Enter a number" id="ansInput" value="${UI.esc(a ?? "")}">`;
    } else if (q.type === "short_answer") {
      input = `<input class="form-control form-control-lg" placeholder="Type your answer" id="ansInput" maxlength="500" value="${UI.esc(a ?? "")}">`;
    } else {
      input = `<textarea class="form-control" rows="${q.type === "coding" ? 14 : 8}" id="ansInput" placeholder="${q.type === "coding" ? "Write your code here" : "Write your answer here"}" maxlength="20000" ${q.type === "coding" ? 'style="font-family:monospace"' : ""}>${UI.esc(a ?? "")}</textarea>`;
    }
    document.getElementById("qBox").innerHTML = `
      <div class="d-flex flex-wrap gap-2 align-items-center mb-3"><span class="badge text-bg-primary">Question ${idx + 1} of ${Q.length}</span><span class="badge text-bg-light" title="Time spent on this question"><i class="bi bi-stopwatch me-1"></i><span id="qTimer">${UI.duration(qtime[q.id] || 0)}</span></span>
      ${q.section ? `<span class="badge text-bg-light">${UI.esc(q.section)}</span>` : ""}
      <span class="small text-secondary ms-auto">+${UI.num(q.marks)} marks${q.negative ? ` · <span class="text-danger">−${UI.num(q.negative)} for wrong</span>` : ""}</span></div>
      <div class="question-text mb-3">${UI.safeHtml(q.text)}</div>
      ${q.media.map((m) => m.type === "image" || m.type === "equation" ? `<div class="q-media mb-3"><img src="${UI.esc(m.url)}" alt="Question image"></div>` : m.type === "audio" ? `<audio controls src="${UI.esc(m.url)}" class="mb-3"></audio>` : m.type === "video" ? `<video controls src="${UI.esc(m.url)}" class="mb-3 w-100"></video>` : `<a href="${UI.esc(m.url)}" target="_blank" rel="noopener">Open attachment</a>`).join("")}
      <div id="answerArea">${input}</div>`;
    document.querySelectorAll(".option-item").forEach((o) => o.addEventListener("click", () => {
      if (o.dataset.multi) { const cur = new Set(Array.isArray(answers[q.id]) ? answers[q.id] : []); cur.has(o.dataset.key) ? cur.delete(o.dataset.key) : cur.add(o.dataset.key); answers[q.id] = [...cur].sort(); }
      else answers[q.id] = o.dataset.key;
      changed(); renderQ();
    }));
    const inp = document.getElementById("ansInput");
    if (inp) inp.addEventListener("input", () => { answers[q.id] = inp.value === "" ? null : (q.type === "numerical" ? inp.value : inp.value); changed(false); });
    document.getElementById("prevBtn").disabled = idx === 0;
    document.getElementById("nextBtn").innerHTML = idx === Q.length - 1 ? 'Save <i class="bi bi-check2"></i>' : 'Save & next <i class="bi bi-chevron-right"></i>';
    document.getElementById("flagBtn").classList.toggle("active", flagged.has(q.id));
    renderPalette();
  }
  function renderPalette() {
    visited.add(Q[idx]?.id);
    document.getElementById("palette").innerHTML = Q.map((q, i) => `<button class="${isAnswered(q) ? "answered" : visited.has(q.id) ? "visited" : ""} ${flagged.has(q.id) ? "flagged" : ""} ${i === idx ? "current" : ""}" data-i="${i}" title="Question ${i + 1}">${i + 1}</button>`).join("");
    const ans = Q.filter(isAnswered).length;
    document.getElementById("summary").innerHTML = `Answered: <strong>${ans}</strong> / ${Q.length}<br>Not answered: <strong>${Q.filter((q) => visited.has(q.id) && !isAnswered(q)).length}</strong> · Not visited: <strong>${Q.filter((q) => !visited.has(q.id)).length}</strong><br>Marked for review: <strong>${flagged.size}</strong>`;
  }
  document.getElementById("palette").addEventListener("click", (e) => { const b = e.target.closest("[data-i]"); if (b) { idx = Number(b.dataset.i); renderQ(); } });
  document.getElementById("prevBtn").onclick = () => { if (idx > 0) { idx--; renderQ(); } };
  document.getElementById("nextBtn").onclick = () => { save(); if (idx < Q.length - 1) { idx++; renderQ(); } else UI.toast("Answer saved."); };
  document.getElementById("flagBtn").onclick = () => { const id = Q[idx].id; flagged.has(id) ? flagged.delete(id) : flagged.add(id); changed(); renderQ(); };
  document.getElementById("clearBtn").onclick = () => { delete answers[Q[idx].id]; changed(); renderQ(); };
  document.getElementById("submitBtn").onclick = () => submit(false);
  document.getElementById("instrBtn")?.addEventListener("click", () => UI.modal({ title: "Instructions", body: `<div style="white-space:pre-wrap">${UI.esc(d.exam.instructions)}</div>` }));

  // ---------- saving ----------
  function changed(redraw = true) {
    dirty = true;
    try { localStorage.setItem(backupKey, JSON.stringify({ answers, at: Date.now() })); } catch { /* ignore */ }
    setSaveState("pending");
    if (!redraw) renderPalette();
  }
  function setSaveState(s) {
    const map = { pending: '<i class="bi bi-cloud-arrow-up"></i> Saving…', ok: '<i class="bi bi-cloud-check"></i> Saved', fail: '<i class="bi bi-cloud-slash text-danger"></i> Not saved – retrying' };
    document.getElementById("saveState").innerHTML = map[s];
  }
  let saving = false;
  async function save() {
    if (!dirty || saving || submitted) return;
    saving = true; dirty = false;
    try {
      const r = await API.call("student.saveAnswers", { attempt_id: d.attempt.id, answers, tab_switches: tabSwitches, flagged: [...flagged], qtime });
      if (typeof r.remaining_seconds === "number" && Math.abs(r.remaining_seconds - remaining) > 5) remaining = r.remaining_seconds; // sync with server clock
      setSaveState("ok");
    } catch (e) {
      dirty = true; setSaveState("fail");
      if (e.status === 409) { submitted = true; await UI.warn(e.message); submit(true, true); }
    } finally { saving = false; }
  }
  setInterval(save, 15000);

  // ---------- timer ----------
  const timerEl = document.getElementById("timer");
  const tick = () => {
    if (submitted) return;
    remaining = Math.max(0, remaining - 1);
    const h = Math.floor(remaining / 3600), m = Math.floor((remaining % 3600) / 60), s = remaining % 60;
    timerEl.textContent = `${h ? h + ":" : ""}${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    timerEl.classList.toggle("low", remaining <= 300);
    if (remaining === 300) UI.toast("5 minutes left!", "warning");
    if (remaining === 60) UI.toast("1 minute left!", "warning");
    if (remaining <= 0) submit(true);
  };
  tick(); setInterval(tick, 1000);

  // ---------- integrity ----------
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && !submitted) { tabSwitches++; dirty = true; save(); }
    else if (!submitted && tabSwitches) UI.toast(`Leaving the exam tab is recorded (${tabSwitches} time${tabSwitches > 1 ? "s" : ""}).`, "warning");
  });
  document.addEventListener("contextmenu", (e) => e.preventDefault());
  ["copy", "cut", "paste"].forEach((ev) => document.addEventListener(ev, (e) => { if (!e.target.matches("textarea,input")) e.preventDefault(); }));
  window.addEventListener("beforeunload", (e) => { if (!submitted) { save(); e.preventDefault(); e.returnValue = ""; } });

  // ---------- submit ----------
  async function submit(auto, force = false) {
    if (submitting || (submitted && !force)) return;
    if (!auto) {
      const left = Q.length - Q.filter(isAnswered).length;
      const ok = await UI.confirm(`${left ? `You have ${left} unanswered question${left > 1 ? "s" : ""}. ` : "All questions answered. "}${flagged.size ? `${flagged.size} marked for review. ` : ""}\nYou can't change your answers after submitting.`, { title: "Submit exam?", confirmText: "Yes, submit", icon: "warning" });
      if (!ok) return;
    }
    submitting = true; submitted = true;
    UI.loading(true, auto ? "Time is up – submitting your answers…" : "Submitting…");
    let r = null;
    for (let i = 0; i < 3 && !r; i++) {
      try { r = await API.call("student.submitExam", { attempt_id: d.attempt.id, answers, tab_switches: tabSwitches, auto, qtime }); }
      catch (e) {
        if (e.status === 409) { r = { message: e.message, already: true }; break; }
        if (i === 2) { UI.loading(false); submitting = false; submitted = false; await UI.error(`${e.message}\n\nYour answers are kept on this device. Please press Submit again.`, "Couldn't submit"); return; }
        await new Promise((res) => setTimeout(res, 2000));
      }
    }
    UI.loading(false);
    try { localStorage.removeItem(backupKey); } catch { /* ignore */ }
    if (r.already) await UI.info(r.message, "Already submitted");
    else if (r.show_result) {
      await Swal.fire({ icon: "success", title: "Submitted!", html: `${UI.esc(r.message)}<div class="display-5 fw-bold my-3">${UI.num(r.percentage, 1)}%</div><div>${UI.num(r.score)} / ${UI.num(r.max)} marks</div>`, confirmButtonText: "Go to my results", confirmButtonColor: "#115e59", allowOutsideClick: false });
      location.replace("results.html"); return;
    } else await UI.success(`${r.message}${r.pending_manual ? " Some answers will be graded by your teacher." : ""} Your result will be shown once it is released.`, "Submitted!");
    location.replace("my-exams.html");
  }

  renderQ();
});
