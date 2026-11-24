App.init({ roles: ["super_admin"] }).then(() => {
  new CrudPage("#app", {
    table: "audit_logs", title: "Audit logs", icon: "shield-check", subtitle: "Who changed what, and when",
    canCreate: false, canEdit: false, canDelete: false, pageSize: 50,
    columns: [
      { key: "created_at", label: "When", render: (r) => `<span title="${UI.fmtDateTime(r.created_at)}">${UI.fmtDateTime(r.created_at)}</span>` },
      { key: "actor_email", label: "User" },
      { key: "action", label: "Action", render: (r) => `<span class="badge text-bg-light text-capitalize">${UI.esc(String(r.action).replace(/_/g, " "))}</span>` },
      { key: "entity_type", label: "Item", render: (r) => UI.esc(String(r.entity_type || "").replace(/_/g, " ")) },
      { key: "ip_address", label: "IP" },
    ],
    filters: [{ name: "action", label: "Action", options: ["login", "create", "update", "delete", "bulk_create", "reset_password", "change_password", "exam_status", "syllabus_import"].map((a) => ({ value: a, label: a.replace(/_/g, " ") })) }],
    rowActions: [{ icon: "eye", label: "Details", onClick: (r) => UI.modal({ title: "Audit entry", size: "lg", body: `<pre class="small bg-light p-3 rounded">${UI.esc(JSON.stringify({ action: r.action, entity: r.entity_type, id: r.entity_id, new: r.new_data, old: r.old_data, agent: r.user_agent }, null, 2))}</pre>` }) }],
  });
});
