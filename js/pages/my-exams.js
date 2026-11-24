App.init({ roles: ["student"] }).then(async () => {
  const el = document.getElementById("app");
  el.innerHTML = `<h1 class="page-title mb-3"><i class="bi bi-pencil-square me-2 text-primary"></i>My exams</h1>
    <ul class="nav nav-pills mb-3" id="tabs">${[["active", "Available & upcoming"], ["done", "Completed"], ["all", "All"]].map(([k, l], i) => `<li class="nav-item"><button class="nav-link ${i ? "" : "active"}" data-tab="${k}">${l}</button></li>`).join("")}</ul>
    <div id="list"><div class="text-center py-5"><div class="loader-ring mx-auto"></div></div></div>`;
  let rows = [], tab = "active";
  try { rows = (await API.call("student.exams")).rows; } catch (e) { document.getElementById("list").innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
  const labels = { open: "Available", in_progress: "In progress", upcoming: "Upcoming", attempted: "Attempted", closed: "Closed" };
  const render = () => {
    const list = rows.filter((e) => tab === "all" || (tab === "active" ? ["open", "in_progress", "upcoming"].includes(e.state) : ["attempted", "closed"].includes(e.state)));
    document.getElementById("list").innerHTML = list.length ? `<div class="row g-3">${list.map((e) => `
      <div class="col-md-6 col-xl-4"><div class="card h-100"><div class="card-body d-flex flex-column">
        <div class="d-flex align-items-start gap-2 mb-2"><h5 class="mb-0 flex-grow-1">${UI.esc(e.title)}</h5>${UI.badge(e.state).replace(/>[^<]+</, `>${labels[e.state] || e.state}<`)}</div>
        ${e.exam_category ? `<div class="small mb-2" style="color:${UI.esc(e.exam_category.color || "#115e59")}"><i class="bi bi-bookmark-fill"></i> ${UI.esc(e.exam_category.name)}</div>` : ""}
        ${e.description ? `<p class="small text-secondary clamp-2">${UI.esc(e.description)}</p>` : ""}
        <ul class="list-unstyled small text-secondary mb-3">
          <li><i class="bi bi-clock me-1"></i>${e.duration_minutes} minutes · ${e.total_questions} questions · ${UI.num(e.total_marks)} marks</li>
          ${e.start_time ? `<li><i class="bi bi-calendar-event me-1"></i>Opens ${UI.fmtDateTime(e.start_time)}</li>` : ""}
          ${e.end_time ? `<li><i class="bi bi-calendar-x me-1"></i>Closes ${UI.fmtDateTime(e.end_time)}</li>` : ""}
          <li><i class="bi bi-arrow-repeat me-1"></i>Attempts: ${e.attempts_used} of ${e.attempt_limit || 1}</li>
          ${e.negative_marking ? '<li class="text-danger"><i class="bi bi-dash-circle me-1"></i>Negative marking applies</li>' : ""}
        </ul>
        <div class="mt-auto">${e.state === "open" ? `<button class="btn btn-primary w-100" data-start="${e.id}"><i class="bi bi-play-fill me-1"></i>Start exam</button>`
          : e.state === "in_progress" ? `<button class="btn btn-warning w-100" data-start="${e.id}"><i class="bi bi-arrow-right-circle me-1"></i>Resume exam</button>`
          : e.state === "upcoming" ? `<button class="btn btn-outline-secondary w-100" disabled>Not started yet</button>`
          : `<a class="btn btn-outline-primary w-100" href="results.html">View results</a>`}</div>
      </div></div></div>`).join("")}</div>` : `<div class="card">${UI.empty(tab === "active" ? "No exams available right now." : "Nothing here yet.", "pencil-square")}</div>`;
    document.querySelectorAll("[data-start]").forEach((b) => b.addEventListener("click", () => start(rows.find((x) => x.id === b.dataset.start))));
  };
  document.getElementById("tabs").addEventListener("click", (e) => { const b = e.target.closest("[data-tab]"); if (!b) return; tab = b.dataset.tab; document.querySelectorAll("#tabs .nav-link").forEach((x) => x.classList.toggle("active", x === b)); render(); });
  async function start(e) {
    if (e.state === "open" && !(await UI.confirm(`You will have ${e.duration_minutes} minutes once you start. The timer keeps running even if you close the page.\n\nThis uses attempt ${e.attempts_used + 1} of ${e.attempt_limit || 1}.`, { title: "Start the exam?", confirmText: "Start now", icon: "info" }))) return;
    location.href = `exam-take.html?id=${e.id}`;
  }
  render();
});
