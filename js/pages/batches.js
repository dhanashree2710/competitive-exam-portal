App.init({ roles: App.STAFF }).then((user) => {
  const admin = App.isAdmin();
  new CrudPage("#app", {
    table: "batches", title: "Batches", icon: "people", singular: "batch", subtitle: "Groups of students – assign exams and assignments to a batch",
    canCreate: admin, canEdit: admin, canDelete: admin,
    deleteWarning: "Members, exam and assignment links of this batch will also be removed.",
    columns: [
      { key: "name", label: "Batch", render: (r) => `<a class="batch-link" href="batch-view.html?id=${r.id}"><span class="bl-ico"><i class="bi bi-collection"></i></span><span><b>${UI.esc(r.name)}</b><small>${UI.esc(r.code || "")}${r.code ? " · " : ""}Open details <i class="bi bi-arrow-right-short"></i></small></span></a>` },
      { key: "academic_year", label: "Year" },
      { key: "exam_category.name", label: "Exam category" },
      { key: "organization.name", label: "Organization" },
      { key: "start_date", label: "Dates", render: (r) => `${UI.fmtDate(r.start_date)} – ${UI.fmtDate(r.end_date)}` },
      { key: "is_active", label: "Status", render: (r) => UI.activeBadge(r.is_active) },
    ],
    filters: [{ name: "organization_id", label: "Organization", options: () => App.options("organizations") }],
    defaults: () => ({ is_active: true, organization_id: user.organization_id || "" }),
    fields: [
      { name: "name", label: "Batch name", required: true, placeholder: "e.g. B.Tech CSE 2025 – Sec A" },
      { name: "code", label: "Code" },
      { name: "organization_id", label: "Organization", type: "select", required: true, options: () => App.options("organizations") },
      { name: "exam_category_id", label: "Exam category", type: "select", options: () => App.options("exam_categories") },
      { name: "academic_year", label: "Academic year", placeholder: "2025-26" },
      { name: "is_active", label: "Active", type: "checkbox" },
      { name: "start_date", label: "Start date", type: "date" },
      { name: "end_date", label: "End date", type: "date" },
      { name: "description", label: "Description", type: "textarea", rows: 2 },
    ],
    rowActions: [{ icon: "eye", text: "Open", label: "Open batch details", class: "btn-primary", onClick: (r) => (location.href = `batch-view.html?id=${r.id}`) },
      { icon: "person-plus", text: "Members", label: "Manage members", class: "btn-outline-primary", onClick: (r) => members(r) }],
  });

  async function members(batch) {
    const m = UI.modal({ title: `Members – ${batch.name}`, size: "lg", body: `<div class="text-center py-4"><div class="loader-ring mx-auto"></div></div>` });
    const load = async () => {
      let r;
      try { r = await API.call("batch.members", { batch_id: batch.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      m.body.innerHTML = `${admin ? `<div class="card mb-3 bg-light"><div class="card-body">
          <label class="form-label">Add people</label>
          <input class="form-control mb-2" placeholder="Filter by name, email or roll number…" data-filter>
          <select class="form-select" multiple size="7" data-pick></select>
          <div class="d-flex mt-2 gap-2 align-items-center"><span class="small text-secondary">Ctrl/Cmd-click to select several.</span>
          <button class="btn btn-primary ms-auto" data-add><i class="bi bi-person-plus me-1"></i>Add selected</button></div></div></div>` : ""}
        <div class="d-flex mb-2"><strong>${r.rows.length} member${r.rows.length === 1 ? "" : "s"}</strong></div>
        <div class="table-responsive"><table class="table table-sm"><thead><tr><th>Name</th><th>Email</th><th>Roll no.</th><th>Role</th><th></th></tr></thead><tbody>
        ${r.rows.length ? r.rows.map((x) => `<tr><td>${UI.esc(x.user?.full_name)}</td><td>${UI.esc(x.user?.email)}</td><td>${UI.esc(x.user?.roll_number || "—")}</td><td class="text-capitalize">${UI.esc(x.role_in_batch || "student")}</td>
          <td class="text-end">${admin ? `<button class="btn btn-sm btn-light text-danger" data-remove="${x.id}" title="Remove"><i class="bi bi-x-lg"></i></button>` : ""}</td></tr>`).join("") : `<tr><td colspan="5">${UI.empty("No members yet.", "people")}</td></tr>`}
        </tbody></table></div>`;
      m.body.querySelectorAll("[data-remove]").forEach((b) => b.addEventListener("click", async () => {
        if (!(await UI.confirm("Remove this person from the batch?", { confirmText: "Remove", danger: true }))) return;
        if (await UI.run(() => API.call("batch.removeMember", { id: b.dataset.remove }))) load();
      }));
      if (admin) {
        const inBatch = new Set(r.rows.map((x) => x.user?.id));
        const people = (await App.lookup("members", { organization_id: batch.organization_id })).filter((p) => !inBatch.has(p.id));
        const sel = m.body.querySelector("[data-pick]");
        const fill = (q = "") => { q = q.toLowerCase(); sel.innerHTML = people.filter((p) => !q || `${p.full_name} ${p.email} ${p.roll_number || ""}`.toLowerCase().includes(q)).map((p) => `<option value="${p.id}">${UI.esc(p.full_name)} · ${UI.esc(p.email)}${p.roll_number ? " · " + UI.esc(p.roll_number) : ""} (${UI.roleLabel(p.role)})</option>`).join("") || `<option disabled>No more people to add from this organization</option>`; };
        fill();
        m.body.querySelector("[data-filter]").addEventListener("input", (e) => fill(e.target.value));
        m.body.querySelector("[data-add]").addEventListener("click", async () => {
          const ids = [...sel.selectedOptions].map((o) => o.value).filter(Boolean);
          if (!ids.length) return UI.warn("Please select at least one person from the list.");
          if (await UI.run(() => API.call("batch.addMembers", { batch_id: batch.id, user_ids: ids }), { loading: "Adding…" })) { App.clearLookup(); load(); }
        });
      }
    };
    load();
  }
});
