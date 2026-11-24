App.init({ roles: ["super_admin", "college_admin"] }).then((user) => {
  const isSuper = user.role === "super_admin";
  const adminRoleFor = (type) => (type === "college" ? "College Admin" : type === "institute" ? "Institute Admin" : "Super Admin");
  const pw = (v) => (v && (v.length < 8 || !/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) ? "Use at least 8 characters with letters and numbers." : "");
  // the admin block is required when creating a college/institute; optional ("add another admin") when editing
  const needAdmin = (v, row) => !row && v.type !== "root";
  const adminVisible = (row) => (v) => !row || v.add_admin;

  const page = new CrudPage("#app", {
    table: "organizations", title: "Organizations", icon: "building", singular: "organization",
    subtitle: isSuper ? "Colleges and institutes using the portal, with their admins" : "Institutes under your college, with their admins",
    columns: [
      { key: "name", label: "Name", render: (r) => `<div class="fw-semibold">${UI.esc(r.name)}</div><div class="small text-secondary">${UI.esc(r.code || "")}</div>` },
      { key: "type", label: "Type", render: (r) => `<span class="badge text-bg-light text-capitalize">${UI.esc(r.type)}</span>` },
      { key: "parent.name", label: "Parent" },
      { key: "admins", label: "Admin", render: (r) => (r.admins || []).length
          ? r.admins.map((a) => `<div class="small"><i class="bi bi-person-badge text-primary me-1"></i><span class="fw-semibold">${UI.esc(a.full_name)}</span> <span class="text-secondary">${UI.esc(a.email)}</span></div>`).join("")
          : '<span class="badge text-bg-warning">No admin yet</span>' },
      { key: "city", label: "City" },
      { key: "is_active", label: "Status", render: (r) => UI.activeBadge(r.is_active) },
    ],
    filters: isSuper ? [{ name: "type", label: "Type", options: [{ value: "root", label: "Root" }, { value: "college", label: "College" }, { value: "institute", label: "Institute" }] }] : [],
    canDelete: isSuper ? (r) => r.type !== "root" : false,
    canEdit: (r) => isSuper || r.type === "institute" || r.id === user.organization_id,
    defaults: () => ({ type: isSuper ? "college" : "institute", is_active: true, parent_id: isSuper ? "" : user.organization_id }),
    fields: (row) => [
      { name: "name", label: "Name", required: true },
      { name: "code", label: "Code", placeholder: "Short unique code, e.g. ABC-01" },
      { name: "type", label: "Type", type: "select", required: true, disabled: !isSuper || !!row,
        options: isSuper ? [{ value: "college", label: "College" }, { value: "institute", label: "Institute" }, { value: "root", label: "Root (head office)" }] : [{ value: "institute", label: "Institute" }] },
      { name: "parent_id", label: "Parent organization", type: "select", disabled: !isSuper, placeholder: "— None —", help: "Institutes usually belong to a college.",
        options: async () => (await App.lookup("organizations")).filter((o) => o.id !== row?.id && o.type !== "institute").map((o) => ({ value: o.id, label: `${o.name} (${o.type})` })) },
      { name: "city", label: "City" },
      { name: "contact_email", label: "Contact email", type: "email" },
      { name: "address", label: "Address", type: "textarea", rows: 2 },
      { name: "logo_url", label: "Logo", type: "upload", purpose: "logo", accept: "image/*", buttonText: "Upload logo", hint: "PNG/JPG/SVG, max 10 MB" },
      { name: "is_active", label: "Active", type: "checkbox" },

      // ---------- admin account ----------
      { name: "admin_heading", type: "html", col: "col-12", render: (el, vals, form) => {
          const draw = () => {
            const t = form.querySelector('[name="type"]')?.value || vals.type;
            el.innerHTML = `<div class="border-top pt-3 mt-1"><div class="fw-semibold"><i class="bi bi-person-badge me-1 text-primary"></i>${row ? "Organization admin" : `${adminRoleFor(t)} account`}</div>
              <div class="small text-secondary">${row
                ? ((row.admins || []).length ? "Current: " + row.admins.map((a) => UI.esc(`${a.full_name} (${a.email})`)).join(", ") : "This organization has no admin yet.")
                : `This person will sign in and manage this ${t === "root" ? "head office" : t}. Required for colleges and institutes.`}</div></div>`;
          };
          draw(); form.addEventListener("change", (e) => { if (e.target.name === "type") draw(); });
        } },
      ...(row ? [{ name: "add_admin", label: (row.admins || []).length ? "Add another admin" : "Create an admin now", type: "checkbox", col: "col-12" }] : []),
      { name: "admin_full_name", label: "Admin full name *", visible: adminVisible(row), validate: (v, all) => ((needAdmin(all, row) || all.add_admin) && !v ? "Admin full name is required." : "") },
      { name: "admin_email", label: "Admin email (login) *", type: "email", visible: adminVisible(row), validate: (v, all) => ((needAdmin(all, row) || all.add_admin) && !v ? "Admin email is required." : "") },
      { name: "admin_phone", label: "Admin phone", type: "tel", visible: adminVisible(row) },
      { name: "admin_password", label: "Admin password *", type: "password", visible: adminVisible(row), help: "At least 8 characters, with letters and numbers. Share it with the admin securely.",
        validate: (v, all) => ((needAdmin(all, row) || all.add_admin) && !v ? "Admin password is required." : pw(v)) },
    ],
    rowActions: [{ icon: "person-badge", text: "Admins", label: "Manage this organization's admins", class: "btn-outline-primary", show: (r) => isSuper || r.type === "institute", onClick: (r) => manageAdmins(r) }],
    toSave: (v) => { const d = { ...v }; Object.keys(d).filter((k) => k.startsWith("admin_") || k === "add_admin").forEach((k) => delete d[k]); return d; },
    toParams: (v, row) => (v.admin_email && (!row || v.add_admin)
      ? { admin: { full_name: v.admin_full_name, email: v.admin_email, phone: v.admin_phone, password: v.admin_password } } : {}),
    afterSave: (saved, isNew, v) => { if (v.admin_email && (isNew || v.add_admin)) UI.success(`${saved.name} is ready.\n\nAdmin login: ${v.admin_email}\nShare the password with them securely. They can change it from My Profile.`, "Organization & admin created"); },
  });

  // ---------- organization admins: list / add / edit / reset password / deactivate / delete ----------
  async function manageAdmins(org) {
    const m = UI.modal({ title: `Admins – ${org.name}`, size: "lg", body: `<div class="text-center py-4"><span class="spinner-border text-primary"></span></div>` });
    const load = async () => {
      let r;
      try { r = await API.call("org.admins", { organization_id: org.id }); } catch (e) { m.body.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
      const roleName = UI.roleLabel(r.admin_role);
      m.body.innerHTML = `<div class="d-flex align-items-center mb-3"><div class="small text-secondary">Admins of a ${UI.esc(r.organization.type)} get the <b>${roleName}</b> role automatically.</div>
          <button class="btn btn-primary btn-sm ms-auto" data-add><i class="bi bi-person-plus me-1"></i>Add admin</button></div>
        ${r.rows.length ? `<div class="list-group">${r.rows.map((a) => `<div class="list-group-item d-flex flex-wrap gap-2 align-items-center">
          <span class="avatar">${UI.esc(UI.initials(a.full_name))}</span>
          <div class="flex-grow-1"><div class="fw-semibold">${UI.esc(a.full_name)} ${a.is_active === false ? '<span class="badge text-bg-secondary">Inactive</span>' : ""} ${a.locked ? '<span class="badge text-bg-danger">Locked</span>' : ""}</div>
            <div class="small text-secondary">${UI.esc(a.email)}${a.phone ? " · " + UI.esc(a.phone) : ""} · ${UI.roleLabel(a.role)} · last sign-in ${a.last_login_at ? UI.timeAgo(a.last_login_at) : "never"}</div></div>
          <div class="btn-group btn-group-sm">
            <button class="btn btn-light" data-edit="${a.id}" title="Edit"><i class="bi bi-pencil"></i></button>
            <button class="btn btn-light" data-pw="${a.id}" title="Reset password"><i class="bi bi-key"></i></button>
            <button class="btn btn-light" data-toggle="${a.id}" title="${a.is_active === false ? "Activate" : "Deactivate"}"><i class="bi bi-${a.is_active === false ? "toggle-off" : "toggle-on"}"></i></button>
            ${a.role !== "super_admin" ? `<button class="btn btn-light text-danger" data-del="${a.id}" title="Delete"><i class="bi bi-trash"></i></button>` : ""}</div></div>`).join("")}</div>`
          : `<div class="alert alert-warning mb-0"><i class="bi bi-exclamation-triangle me-1"></i>This organization has no admin yet. Click <b>Add admin</b> to create one.</div>`}`;
      const find = (id) => r.rows.find((x) => x.id === id);
      const pwCheck = (v) => (v && (v.length < 8 || !/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) ? "Use at least 8 characters with letters and numbers." : "");
      const form = (a) => UI.formModal({
        title: a ? `Edit admin – ${a.full_name}` : `New ${roleName}`, size: "", submitText: a ? "Save" : "Create admin",
        values: a || { is_active: true },
        fields: [
          { name: "full_name", label: "Full name", required: true, col: "col-12" },
          { name: "email", label: "Email (used to sign in)", type: "email", required: true, col: "col-12" },
          { name: "phone", label: "Phone", type: "tel", col: "col-12" },
          ...(a ? [] : [{ name: "password", label: "Password", type: "password", required: true, col: "col-12", validate: pwCheck, help: "At least 8 characters with letters and numbers." }]),
          { name: "is_active", label: "Active (can sign in)", type: "checkbox", col: "col-12" },
        ],
        onSubmit: async (v) => { const res = await API.call("org.saveAdmin", { organization_id: org.id, id: a?.id, ...v }); UI.toast(res.message); load(); page.reload(); },
      });
      m.body.querySelector("[data-add]").onclick = () => form(null);
      m.body.querySelectorAll("[data-edit]").forEach((b) => (b.onclick = () => form(find(b.dataset.edit))));
      m.body.querySelectorAll("[data-pw]").forEach((b) => (b.onclick = () => UI.formModal({
        title: `Reset password – ${find(b.dataset.pw).full_name}`, size: "", submitText: "Reset password",
        fields: [{ name: "password", label: "New password", type: "password", required: true, col: "col-12", validate: pwCheck }],
        onSubmit: async (v) => { const res = await API.call("users.resetPassword", { id: b.dataset.pw, password: v.password }); UI.success(res.message); },
      })));
      m.body.querySelectorAll("[data-toggle]").forEach((b) => (b.onclick = async () => {
        const a = find(b.dataset.toggle); const on = a.is_active === false;
        if (!on && !(await UI.confirm(`${a.full_name} won't be able to sign in until reactivated.`, { title: "Deactivate admin?", confirmText: "Deactivate", danger: true }))) return;
        if (await UI.run(() => API.call("org.saveAdmin", { organization_id: org.id, id: a.id, full_name: a.full_name, email: a.email, phone: a.phone, is_active: on }), { success: on ? "Admin activated." : "Admin deactivated." })) { load(); page.reload(); }
      }));
      m.body.querySelectorAll("[data-del]").forEach((b) => (b.onclick = async () => {
        const a = find(b.dataset.del);
        if (!(await UI.confirm(`${a.full_name}'s account will be permanently deleted.`, { title: "Delete admin?", confirmText: "Delete", danger: true }))) return;
        if (await UI.run(() => API.call("crud.delete", { table: "users", id: a.id }))) { load(); page.reload(); }
      }));
    };
    load();
  }
});
