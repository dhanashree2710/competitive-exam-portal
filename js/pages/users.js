App.init({ roles: App.ADMIN }).then((user) => {
  const RANK = { super_admin: 5, college_admin: 4, institute_admin: 3, faculty: 2, student: 1 };
  const allowedRoles = Object.keys(RANK).filter((r) => user.role === "super_admin" || RANK[user.role] > RANK[r]);
  const roleOpts = allowedRoles.map((r) => ({ value: r, label: UI.roleLabel(r) }));
  const orgOpts = () => App.options("organizations", {}, (o) => `${o.name} (${o.type})`);
  const pw = (v) => (v && (v.length < 8 || !/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) ? "Use at least 8 characters with letters and numbers." : "");
  const manageable = (r) => r.id !== user.id && (user.role === "super_admin" || RANK[user.role] > RANK[r.role]);

  const page = new CrudPage("#app", {
    table: "users", title: "Users", icon: "person-badge", singular: "user", createLabel: "Add user",
    subtitle: "Admins, faculty and students",
    columns: [
      { key: "full_name", label: "Name", render: (r) => `<div class="d-flex align-items-center gap-2"><span class="avatar">${UI.esc(UI.initials(r.full_name))}</span><div><div class="fw-semibold">${UI.esc(r.full_name)}</div><div class="small text-secondary">${UI.esc(r.email)}</div></div></div>` },
      { key: "role", label: "Role", render: (r) => `<span class="badge text-bg-light">${UI.roleLabel(r.role)}</span>` },
      { key: "roll_number", label: "Roll no." },
      { key: "organization.name", label: "Organization" },
      { key: "last_login_at", label: "Last sign-in", render: (r) => r.last_login_at ? UI.timeAgo(r.last_login_at) : '<span class="text-secondary">Never</span>' },
      { key: "is_active", label: "Status", render: (r) => r.locked_until && new Date(r.locked_until) > new Date() ? '<span class="badge text-bg-danger">Locked</span>' : UI.activeBadge(r.is_active) },
    ],
    filters: [
      { name: "role", label: "Role", options: Object.keys(RANK).filter((r) => user.role === "super_admin" || r !== "super_admin").map((r) => ({ value: r, label: UI.roleLabel(r) })) },
      { name: "organization_id", label: "Organization", options: orgOpts },
      { name: "is_active", label: "Status", options: [{ value: "true", label: "Active" }, { value: "false", label: "Inactive" }] },
    ],
    canEdit: (r) => r.id === user.id || manageable(r),
    canDelete: manageable,
    deleteWarning: "Tip: users with exam history can't be deleted – deactivate them instead.",
    defaults: () => ({ role: "student", is_active: true, organization_id: user.organization_id || "" }),
    fields: (row) => [
      { name: "full_name", label: "Full name", required: true },
      { name: "email", label: "Email", type: "email", required: true },
      { name: "role", label: "Role", type: "select", required: true, options: roleOpts, disabled: row?.id === user.id },
      { name: "organization_id", label: "Organization", type: "select", options: orgOpts, required: true, visible: (v) => v.role !== "super_admin" },
      { name: "roll_number", label: "Roll number", visible: (v) => v.role === "student" },
      { name: "phone", label: "Phone", type: "tel" },
      { name: "password", label: row ? "New password (leave empty to keep)" : "Password", type: "password", required: !row, validate: pw, help: "At least 8 characters, with letters and numbers." },
      { name: "is_active", label: "Active", type: "checkbox", disabled: row?.id === user.id },
    ],
    toSave: (v) => { const d = { ...v }; if (d.role === "super_admin") d.organization_id = null; if (!d.password) delete d.password; return d; },
    rowActions: [
      { icon: "mortarboard", label: "Full student record", class: "btn-light text-primary", show: (r) => r.role === "student", onClick: (r) => (location.href = `students.html?id=${r.id}`) },
      { icon: "key", label: "Reset password", show: manageable, onClick: resetPassword },
      { icon: "unlock", label: "Unlock account", class: "btn-light text-warning", show: (r) => r.locked_until && new Date(r.locked_until) > new Date() && manageable(r), onClick: async (r) => { if (await UI.run(() => API.call("users.unlock", { id: r.id }))) page.reload(); } },
    ],
    headerActions: [{ label: "Bulk import", icon: "upload", onClick: () => bulkImport() }],
  });

  async function resetPassword(r) {
    await UI.formModal({
      title: `Reset password – ${r.full_name}`, size: "", submitText: "Reset password",
      fields: [{ name: "password", label: "New password", type: "password", required: true, col: "col-12", validate: pw, help: "Share it with the user securely. They will be signed out everywhere." }],
      onSubmit: async (v) => { const res = await API.call("users.resetPassword", { id: r.id, password: v.password }); UI.success(res.message); },
    });
  }

  async function bulkImport() {
    const v = await UI.formModal({
      title: "Bulk import users", submitText: "Import",
      fields: [
        { name: "role", label: "Role for all rows", type: "select", required: true, options: roleOpts.filter((o) => ["student", "faculty"].includes(o.value)), default: "student" },
        { name: "organization_id", label: "Organization", type: "select", required: true, options: orgOpts, default: user.organization_id || "" },
        { name: "batch_id", label: "Add to batch (optional)", type: "select", placeholder: "— No batch —", watch: ["organization_id"], options: async (vals) => vals.organization_id ? App.options("batches", { organization_id: vals.organization_id }) : [] },
        { name: "default_password", label: "Default password", type: "password", help: "Used for rows without a password column.", validate: pw },
        { name: "csv", label: "Paste CSV", type: "textarea", rows: 8, required: true,
          help: "First line must be the header. Columns: <code>full_name,email,roll_number,phone,password</code> (only full_name and email are required). Max 1000 rows.",
          placeholder: "full_name,email,roll_number\nRahul Sharma,(email),21CS001" },
      ],
    });
    if (!v) return;
    const rows = parseCsv(v.csv);
    if (!rows.length) return UI.warn("No rows were found. Make sure the first line is the header (full_name,email,…).");
    if (rows.length > 1000) return UI.warn("Please import at most 1000 rows at a time.");
    if (!v.default_password && rows.some((r) => !r.password)) return UI.warn("Some rows have no password. Please set a default password.");
    let created = 0; const problems = [];
    try {
      for (let i = 0; i < rows.length; i += 25) {
        UI.loading(true, `Importing ${Math.min(i + 25, rows.length)} of ${rows.length}…`);
        const r = await API.call("users.bulkCreate", { rows: rows.slice(i, i + 25), role: v.role, organization_id: v.organization_id, batch_id: v.batch_id || null, default_password: v.default_password || null });
        created += r.created;
        problems.push(...r.report.filter((x) => !x.ok));
      }
    } catch (e) { UI.loading(false); return UI.handle(e); }
    UI.loading(false);
    page.reload();
    if (!problems.length) return UI.success(`${created} user${created === 1 ? "" : "s"} imported successfully.`);
    const list = problems.slice(0, 15).map((p) => `Line ${p.line} (${p.email || "no email"}): ${p.reason}`).join("\n");
    UI.warn(`${created} imported, ${problems.length} skipped:\n\n${list}${problems.length > 15 ? "\n…" : ""}`, "Import finished");
  }

  function parseCsv(text) {
    const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
    if (lines.length < 2) return [];
    const split = (l) => { const out = []; let cur = "", q = false; for (const ch of l) { if (ch === '"') q = !q; else if (ch === "," && !q) { out.push(cur.trim()); cur = ""; } else cur += ch; } out.push(cur.trim()); return out; };
    const head = split(lines[0]).map((h) => h.toLowerCase().replace(/\s+/g, "_").replace(/^name$/, "full_name"));
    return lines.slice(1).map((l, i) => { const c = split(l); const o = { _line: i + 2 }; head.forEach((h, j) => (o[h] = c[j] ?? "")); return o; });
  }
});
