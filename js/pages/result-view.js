App.init().then(async (user) => {
  const el = document.getElementById("app");
  const id = UI.qs("id");
  const load = async () => {
    el.innerHTML = `<div class="text-center py-5"><div class="loader-ring mx-auto"></div></div>`;
    let d;
    try { d = await API.call("result.detail", { id }); } catch (e) { el.innerHTML = `<div class="card">${UI.empty(e.message, "exclamation-circle")}</div>`; return; }
    const r = d.result;
    const pass = Number(r.percentage) >= Number(r.exam?.pass_percentage ?? 33);
    const counts = d.review.reduce((a, q) => { a[q.status] = (a[q.status] || 0) + 1; return a; }, {});
    const back = user.role === "student" ? "results.html" : `results.html?exam=${r.exam_id}`;
    const ansText = (q, v) => {
      if (v === null || v === undefined || v === "" || (Array.isArray(v) && !v.length)) return '<span class="text-secondary">Not answered</span>';
      if (q.options?.length && q.type !== "true_false") { const keys = (Array.isArray(v) ? v : [v]).map(String); return keys.map((k) => { const o = q.options.find((x) => x.key === k); return `<strong>${UI.esc(k)}</strong>${o ? ". " + UI.safeHtml(o.text) : ""}`; }).join("<br>"); }
      if (q.type === "numerical" && typeof v === "object") return `${UI.esc(v.value)}${v.tolerance ? ` (± ${UI.esc(v.tolerance)})` : ""}`;
      if (Array.isArray(v)) return UI.esc(v.join(" / "));
      return `<span style="white-space:pre-wrap">${UI.esc(v)}</span>`;
    };
    const statusIcon = { correct: "check-circle-fill text-success", wrong: "x-circle-fill text-danger", unattempted: "dash-circle text-secondary", manual: "hourglass-split text-warning", partial: "circle-half text-warning" };
    el.innerHTML = `<div class="mb-3 no-print"><a href="${back}" class="small text-decoration-none"><i class="bi bi-arrow-left"></i> Back to results</a>
      <div class="float-end d-flex gap-2">
        ${r.scorecard_url ? `<button class="btn btn-sm btn-outline-success" id="openCard"><i class="bi bi-file-earmark-check me-1"></i>Saved scorecard</button>` : ""}
        <button class="btn btn-sm btn-primary" id="pdfCard"><i class="bi bi-file-earmark-pdf me-1"></i>PDF scorecard</button>
        <button class="btn btn-sm btn-light" onclick="window.print()"><i class="bi bi-printer me-1"></i>Print</button></div></div>
      <div class="card mb-3"><div class="card-body"><div class="row g-3 align-items-center">
        <div class="col-md-5"><h1 class="page-title">${UI.esc(r.exam?.title)}</h1><div class="text-secondary">${UI.esc(r.user?.full_name)}${r.user?.roll_number ? " · " + UI.esc(r.user.roll_number) : ""}</div>
        <div class="small text-secondary">Submitted ${UI.fmtDateTime(r.attempt?.submitted_at)} · Attempt ${r.attempt?.attempt_number ?? 1}</div></div>
        <div class="col-md-7"><div class="row text-center g-2">
          ${[["Score", `${UI.num(r.total_score)}/${UI.num(r.max_score)}`], ["Percentage", UI.num(r.percentage, 1) + "%"], ["Rank", r.rank ?? "—"], ["Accuracy", UI.num(r.accuracy, 1) + "%"], ["Time", UI.duration(r.time_spent_seconds)]].map(([l, v]) => `<div class="col"><div class="fw-bold fs-5">${v}</div><div class="small text-secondary">${l}</div></div>`).join("")}
          <div class="col"><span class="badge fs-6 text-bg-${pass ? "success" : "danger"}">${pass ? "PASS" : "FAIL"}</span></div>
        </div></div></div>
        <div class="d-flex align-items-center gap-3 mt-3 pt-3 border-top"><div id="qr" style="width:96px;height:96px"></div>
          <div class="small"><div class="fw-semibold"><i class="bi bi-patch-check text-success me-1"></i>Verified scorecard</div>
          <div class="text-secondary">Scan the QR code to check this result online.</div><div class="text-secondary">Verification code: <b>${UI.esc(r.verify_code)}</b></div>
          ${r.is_visible ? "" : '<div class="text-warning">Verification works after the result is released.</div>'}</div></div>
        <div class="d-flex flex-wrap gap-3 small mt-3">${Object.entries(counts).map(([k, v]) => `<span><i class="bi bi-${statusIcon[k] || "circle"}"></i> ${v} ${k}</span>`).join("")}${r.attempt?.tab_switches ? `<span class="text-warning"><i class="bi bi-window-stack"></i> ${r.attempt.tab_switches} tab switches</span>` : ""}</div>
      </div></div>
      ${r.subject_wise && Object.keys(r.subject_wise).length > 1 ? `<div class="card mb-3"><div class="card-header">Subject-wise</div><div class="table-responsive"><table class="table mb-0"><thead><tr><th>Subject</th><th>Score</th><th>Correct</th><th>Wrong</th><th>Skipped</th></tr></thead><tbody>
        ${Object.entries(r.subject_wise).map(([k, v]) => `<tr><td>${UI.esc(k)}</td><td>${UI.num(v.score)} / ${UI.num(v.max)}</td><td>${v.correct}</td><td>${v.wrong}</td><td>${v.unattempted}</td></tr>`).join("")}</tbody></table></div></div>` : ""}
      <h5 class="mb-3">Answer review</h5>
      ${d.review.map((q, i) => `<div class="card mb-3 review-q ${q.status}"><div class="card-body">
        <div class="d-flex gap-2 mb-2"><strong>Q${i + 1}.</strong><div class="question-text flex-grow-1">${UI.safeHtml(q.text)}</div>
        <div class="text-nowrap text-end"><i class="bi bi-${statusIcon[q.status] || "circle"}"></i> <strong>${UI.num(q.marks)}</strong> / ${UI.num(q.max)}
          ${q.time_seconds != null ? `<div class="small text-secondary"><i class="bi bi-stopwatch"></i> ${UI.duration(q.time_seconds)}</div>` : ""}</div></div>
        <div class="row g-2 small"><div class="col-md-6"><div class="text-secondary">Your answer</div>${ansText(q, q.your_answer)}</div>
        ${["long_answer", "coding", "file_upload"].includes(q.type) ? "" : `<div class="col-md-6"><div class="text-secondary">Correct answer</div>${ansText(q, q.correct_answer)}</div>`}</div>
        ${q.explanation ? `<div class="alert alert-light border small mt-2 mb-0"><strong>Explanation:</strong> ${UI.esc(q.explanation)}</div>` : ""}
        ${d.can_grade && ["manual", "partial"].includes(q.status) || (d.can_grade && ["long_answer", "coding", "file_upload"].includes(q.type) && q.status !== "unattempted") ? `<div class="input-group input-group-sm mt-2 no-print" style="max-width:260px"><span class="input-group-text">Award marks</span><input type="number" class="form-control" min="0" max="${q.max}" step="0.25" value="${q.status === "manual" ? "" : UI.esc(q.marks)}" data-award="${q.id}"><span class="input-group-text">/ ${UI.num(q.max)}</span></div>` : ""}
      </div></div>`).join("")}
      ${d.can_grade && el.querySelector ? `<div class="text-end no-print" id="gradeBar"></div>` : ""}`;
    // PDF scorecard: download it and keep a copy in the "scorecards" bucket
    el.querySelector("#openCard")?.addEventListener("click", () => UI.openFile(r.scorecard_url));
    el.querySelector("#pdfCard").addEventListener("click", async () => {
      const qrEl = el.querySelector("#qr canvas, #qr img");
      let qr = null; try { qr = qrEl ? (qrEl.tagName === "CANVAS" ? qrEl.toDataURL("image/png") : qrEl.src) : null; } catch { qr = null; }
      const blob = await UI.run(() => Exporter.scorecard(r, d.review, qr), { loading: "Creating PDF scorecard…", success: false });
      if (!blob) return;
      const fname = `Scorecard_${(r.user?.full_name || "student").replace(/\W+/g, "_")}_${(r.exam?.title || "exam").replace(/\W+/g, "_")}.pdf`;
      Exporter.download(blob, fname);
      if (user.role !== "student" && !r.is_visible) return UI.toast("Scorecard downloaded.");
      const up = await UI.run(() => API.upload(new File([blob], fname, { type: "application/pdf" }), "scorecard"), { loading: "Saving a copy…", success: false });
      if (up && await UI.run(() => API.call("result.setScorecard", { id: r.id, path: up.path }), { success: "Scorecard downloaded and saved." })) r.scorecard_url = up.path;
    });
    Docs.qr(el.querySelector("#qr"), new URL(`../verify.html?id=${r.id}&code=${r.verify_code}`, location.href).href, 96).catch(() => {});
    const inputs = el.querySelectorAll("[data-award]");
    if (inputs.length) {
      el.querySelector("#gradeBar").innerHTML = `<button class="btn btn-primary" id="saveGrades"><i class="bi bi-save me-1"></i>Save marks</button>`;
      el.querySelector("#saveGrades").onclick = async () => {
        const awards = {}; let bad = false;
        inputs.forEach((i) => { if (i.value === "") return; const v = Number(i.value); if (v < 0 || v > Number(i.max)) { bad = true; i.classList.add("is-invalid"); } else awards[i.dataset.award] = v; });
        if (bad) return UI.warn("Awarded marks must be between 0 and the question's maximum.");
        if (!Object.keys(awards).length) return UI.warn("Enter marks for at least one answer.");
        const res = await UI.run(() => API.call("result.gradeManual", { id, awards }), { quiet: true });
        if (res) { await UI.success(res.message); load(); }
      };
    }
  };
  if (!id) { el.innerHTML = UI.empty("No result selected.", "exclamation-circle"); return; }
  load();
});
