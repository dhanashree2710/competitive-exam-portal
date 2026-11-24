/* Staff results table for one exam – used on exam-edit and results pages */
window.ExamResults = {
  async render(box, examId) {
    box.innerHTML = `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>`;
    let r;
    try { r = await API.call("exam.results", { exam_id: examId }); } catch (e) { box.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    const rows = r.rows;
    const visible = rows.some((x) => x.is_visible);
    const pass = Number(r.exam.pass_percentage ?? 33);
    const avg = rows.length ? rows.reduce((s, x) => s + Number(x.percentage || 0), 0) / rows.length : 0;
    const passed = rows.filter((x) => Number(x.percentage) >= pass).length;
    const pendingManual = rows.filter((x) => x.attempt?.status === "submitted").length;
    box.innerHTML = `
      <div class="row g-3 mb-3">
        ${[["Submitted", rows.length, "people"], ["In progress", r.inProgress, "hourglass-split"], ["Average", UI.num(avg, 1) + "%", "graph-up"], ["Passed", `${passed} / ${rows.length}`, "award"]].map(([l, v, i]) => `
        <div class="col-6 col-md-3"><div class="card stat-card"><div class="card-body d-flex gap-3 align-items-center"><div class="icon" style="background:#f0fdfa;color:#115e59"><i class="bi bi-${i}"></i></div><div><div class="value">${v}</div><div class="small text-secondary">${l}</div></div></div></div></div>`).join("")}
      </div>
      ${pendingManual ? `<div class="alert alert-warning small"><i class="bi bi-pencil me-1"></i>${pendingManual} submission(s) have answers that need manual grading. Open them to award marks before releasing results.</div>` : ""}
      <div class="card"><div class="card-header d-flex flex-wrap gap-2 align-items-center">Results
        <div class="ms-auto d-flex gap-2">
          <button class="btn btn-sm btn-outline-secondary" data-csv ${rows.length ? "" : "disabled"}><i class="bi bi-download me-1"></i>Export CSV</button>
          <button class="btn btn-sm ${visible ? "btn-outline-danger" : "btn-success"}" data-release ${rows.length ? "" : "disabled"}><i class="bi bi-${visible ? "eye-slash" : "send"} me-1"></i>${visible ? "Hide results" : "Release results to students"}</button>
        </div></div>
        <div class="table-responsive"><table class="table table-hover mb-0"><thead><tr><th>Rank</th><th>Student</th><th>Score</th><th>%</th><th>Accuracy</th><th>Time</th><th>Tab switches</th><th>Status</th><th></th></tr></thead><tbody>
        ${rows.length ? rows.map((x) => `<tr>
          <td class="fw-bold">${x.rank ?? "—"}</td>
          <td><div class="fw-semibold">${UI.esc(x.user?.full_name)}</div><div class="small text-secondary">${UI.esc(x.user?.roll_number || x.user?.email || "")}</div></td>
          <td>${UI.num(x.total_score)} / ${UI.num(x.max_score)}</td>
          <td><span class="${Number(x.percentage) >= pass ? "text-success" : "text-danger"} fw-semibold">${UI.num(x.percentage, 1)}%</span></td>
          <td>${UI.num(x.accuracy, 1)}%</td><td>${UI.duration(x.time_spent_seconds)}</td>
          <td>${x.attempt?.tab_switches ? `<span class="badge text-bg-warning">${x.attempt.tab_switches}</span>` : "0"}</td>
          <td>${UI.badge(x.attempt?.status === "submitted" ? "needs grading" : x.attempt?.status)} ${x.is_visible ? '<span class="badge text-bg-light">released</span>' : ""}</td>
          <td><a class="btn btn-sm btn-light" href="result-view.html?id=${x.id}"><i class="bi bi-eye"></i></a></td></tr>`).join("")
        : `<tr><td colspan="9">${UI.empty("No submissions yet.", "bar-chart-line")}</td></tr>`}</tbody></table></div></div>`;
    box.querySelector("[data-release]").onclick = async () => {
      if (!visible && pendingManual && !(await UI.confirm(`${pendingManual} submission(s) still need manual grading. Release anyway?`, { confirmText: "Release anyway" }))) return;
      if (visible && !(await UI.confirm("Students will no longer be able to see their results for this exam.", { title: "Hide results?", confirmText: "Hide", danger: true }))) return;
      if (await UI.run(() => API.call("exam.releaseResults", { exam_id: examId, visible: !visible }))) this.render(box, examId);
    };
    box.querySelector("[data-csv]").onclick = () => {
      const head = ["Rank", "Name", "Email", "Roll number", "Score", "Max", "Percentage", "Accuracy", "Time (s)", "Tab switches", "Status"];
      const lines = [head, ...rows.map((x) => [x.rank, x.user?.full_name, x.user?.email, x.user?.roll_number, x.total_score, x.max_score, x.percentage, x.accuracy, x.time_spent_seconds, x.attempt?.tab_switches, x.attempt?.status])];
      const csv = lines.map((l) => l.map((v) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\r\n");
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob(["﻿" + csv], { type: "text/csv" }));
      a.download = `${r.exam.title.replace(/[^\w]+/g, "_")}_results.csv`; a.click();
      UI.toast("CSV downloaded.");
    };
  },
};
