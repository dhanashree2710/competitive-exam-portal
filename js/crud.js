/* =====================================================================
   crud.js – reusable list/search/paginate/add/edit/delete page component
   ===================================================================== */
(function () {
  const get = (o, path) => path.split(".").reduce((a, k) => (a == null ? a : a[k]), o);

  class CrudPage {
    constructor(el, cfg) {
      this.el = typeof el === "string" ? document.querySelector(el) : el;
      this.cfg = Object.assign({ pageSize: 20, canCreate: true, canEdit: true, canDelete: true, rowActions: [], headerActions: [], filters: [], baseFilters: {} }, cfg);
      this.page = 1; this.search = ""; this.filters = {}; this.rows = []; this.total = 0;
      this.build();
      this.reload();
    }
    can(k, row) { const v = this.cfg[k]; return typeof v === "function" ? v(row) : !!v; }

    build() {
      const c = this.cfg;
      this.el.innerHTML = `
        <div class="page-head">
          <div><h1 class="page-title">${c.icon ? `<i class="bi bi-${c.icon} me-2 text-primary"></i>` : ""}${UI.esc(c.title)}</h1>
          ${c.subtitle ? `<div class="text-secondary small">${UI.esc(c.subtitle)}</div>` : ""}</div>
          <div class="ms-auto d-flex flex-wrap gap-2" data-head></div>
        </div>
        <div class="card">
          <div class="toolbar-bar">
            <div class="search-box"><i class="bi bi-search"></i><input class="form-control" placeholder="Search ${UI.esc((c.title || "").toLowerCase())}…" data-search aria-label="Search">
              <button type="button" class="sb-clear d-none" data-sclear aria-label="Clear search"><i class="bi bi-x-lg"></i></button></div>
            <div class="tb-filters" data-filters></div>
            <button type="button" class="tb-reset d-none" data-reset><i class="bi bi-x-circle me-1"></i>Clear</button>
            <div class="tb-count" data-count></div>
          </div>
          <div class="table-responsive"><table class="table table-hover mb-0"><thead><tr data-thead></tr></thead><tbody data-tbody class="fade-rows"></tbody></table></div>
          <div class="card-footer bg-white d-flex flex-wrap align-items-center gap-2 small" data-pager></div>
        </div>`;
      const head = this.el.querySelector("[data-head]");
      c.headerActions.forEach((a) => {
        if (a.show && !a.show()) return;
        const b = document.createElement("button");
        b.className = `btn ${a.class || "btn-outline-primary"}`; b.innerHTML = `${a.icon ? `<i class="bi bi-${a.icon} me-1"></i>` : ""}${UI.esc(a.label)}`;
        b.addEventListener("click", () => a.onClick(this)); head.appendChild(b);
      });
      if (this.can("canCreate") && c.fields) {
        const b = document.createElement("button");
        b.className = "btn btn-primary"; b.innerHTML = `<i class="bi bi-plus-lg me-1"></i>${UI.esc(c.createLabel || "Add new")}`;
        b.addEventListener("click", () => this.edit(null)); head.appendChild(b);
      }
      const fwrap = this.el.querySelector("[data-filters]");
      c.filters.forEach(async (f) => {
        const col = document.createElement("label"); col.className = "tb-select";
        col.innerHTML = `<span>${UI.esc(f.label)}</span><select class="form-select" title="${UI.esc(f.label)}" data-fname="${UI.esc(f.name)}"><option value="">All</option></select>`;
        fwrap.appendChild(col);
        const sel = col.querySelector("select");
        try {
          const opts = typeof f.options === "function" ? await f.options() : f.options;
          sel.innerHTML += opts.map((o) => `<option value="${UI.esc(o.value ?? o)}">${UI.esc(o.label ?? o)}</option>`).join("");
        } catch (e) { UI.handle(e); }
        const fromLink = UI.qs(f.name);          // e.g. exams.html?status=live opens the list already filtered
        const pre = fromLink || f.default;
        if (pre && [...sel.options].some((o) => o.value === pre)) { sel.value = pre; this.filters[f.name] = pre; col.classList.toggle("on", !!fromLink); if (fromLink) { this.page = 1; this.reload(); this.syncReset(); } }
        sel.addEventListener("change", () => { this.filters[f.name] = sel.value; col.classList.toggle("on", !!sel.value); this.page = 1; this.reload(); this.syncReset(); });
      });
      const sInput = this.el.querySelector("[data-search]"), sClear = this.el.querySelector("[data-sclear]");
      if (UI.qs("q")) { sInput.value = UI.qs("q"); this.search = UI.qs("q"); sClear.classList.remove("d-none"); }
      sInput.addEventListener("input", UI.debounce((e) => { this.search = e.target.value; this.page = 1; this.reload(); this.syncReset(); }));
      sInput.addEventListener("input", () => sClear.classList.toggle("d-none", !sInput.value));
      sClear.addEventListener("click", () => { sInput.value = ""; sClear.classList.add("d-none"); this.search = ""; this.page = 1; this.reload(); this.syncReset(); sInput.focus(); });
      this.el.querySelector("[data-reset]").addEventListener("click", () => {
        sInput.value = ""; sClear.classList.add("d-none"); this.search = "";
        this.el.querySelectorAll("[data-fname]").forEach((x) => { x.value = ""; x.closest(".tb-select").classList.remove("on"); this.filters[x.dataset.fname] = ""; });
        this.page = 1; this.reload(); this.syncReset();
      });
      const cols = [...c.columns.map((col) => `<th class="${col.thClass || ""}">${UI.esc(col.label)}</th>`), `<th class="text-end">Actions</th>`];
      this.el.querySelector("[data-thead]").innerHTML = cols.join("");
    }

    syncReset() {
      const any = !!this.search || Object.values(this.filters).some((v) => v !== "" && v != null);
      this.el.querySelector("[data-reset]")?.classList.toggle("d-none", !any);
    }

    async reload() {
      const tb = this.el.querySelector("[data-tbody]");
      const ncol = this.cfg.columns.length + 1;
      tb.innerHTML = `<tr><td colspan="${ncol}" class="py-3"><div class="skeleton my-1"></div><div class="skeleton my-2" style="width:75%"></div><div class="skeleton" style="width:55%"></div></td></tr>`;
      try {
        const filters = { ...this.cfg.baseFilters, ...Object.fromEntries(Object.entries(this.filters).filter(([, v]) => v !== "")) };
        const r = await API.call("crud.list", { table: this.cfg.table, page: this.page, pageSize: this.cfg.pageSize, search: this.search, filters, order: this.cfg.order, asc: this.cfg.asc });
        this.rows = r.rows; this.total = r.total;
        const cnt = this.el.querySelector("[data-count]"); if (cnt) cnt.innerHTML = `<b>${r.total}</b> ${UI.esc(r.total === 1 ? (this.cfg.singular || "record") : (this.cfg.title || "records").toLowerCase())}`;
        this.renderRows(); this.renderPager();
      } catch (e) {
        tb.innerHTML = `<tr><td colspan="${ncol}">${UI.empty(e.name === "ApiError" ? e.message : "Couldn't load the list. Please refresh.", "exclamation-circle")}</td></tr>`;
      }
    }

    renderRows() {
      const tb = this.el.querySelector("[data-tbody]");
      const c = this.cfg;
      if (!this.rows.length) {
        tb.innerHTML = `<tr><td colspan="${c.columns.length + 1}">${UI.empty(this.search || Object.values(this.filters).some(Boolean) ? "No results match your search." : (c.emptyText || "No records yet."), c.icon || "inbox")}</td></tr>`;
        return;
      }
      tb.innerHTML = "";
      this.rows.forEach((row) => {
        const tr = document.createElement("tr");
        tr.innerHTML = c.columns.map((col) => `<td class="${col.class || ""}">${col.render ? col.render(row) : UI.esc(get(row, col.key) ?? "—")}</td>`).join("") + `<td class="text-end text-nowrap" data-actions></td>`;
        const td = tr.querySelector("[data-actions]");
        const addBtn = (html, cls, title, fn) => { const b = document.createElement("button"); b.className = `btn btn-sm ${cls} ms-1`; b.title = title; b.innerHTML = html; b.addEventListener("click", (e) => { e.stopPropagation(); fn(); }); td.appendChild(b); };
        c.rowActions.forEach((a) => { if (!a.show || a.show(row)) addBtn(`<i class="bi bi-${a.icon}"></i>${a.text ? " " + UI.esc(a.text) : ""}`, a.class || "btn-light", a.label, () => a.onClick(row, this)); });
        if (c.fields && this.can("canEdit", row)) addBtn('<i class="bi bi-pencil"></i>', "btn-light", "Edit", () => this.edit(row));
        if (this.can("canDelete", row)) addBtn('<i class="bi bi-trash"></i>', "btn-light text-danger", "Delete", () => this.remove(row));
        if (c.onRowClick) { tr.classList.add("cursor-pointer"); tr.addEventListener("click", () => c.onRowClick(row, this)); }
        tb.appendChild(tr);
      });
    }

    renderPager() {
      const p = this.el.querySelector("[data-pager]");
      const pages = Math.max(1, Math.ceil(this.total / this.cfg.pageSize));
      const from = this.total ? (this.page - 1) * this.cfg.pageSize + 1 : 0;
      const to = Math.min(this.total, this.page * this.cfg.pageSize);
      p.innerHTML = `<span class="text-secondary">Showing ${from}–${to} of ${this.total}</span>
        <div class="ms-auto btn-group"><button class="btn btn-sm btn-outline-secondary" data-prev ${this.page <= 1 ? "disabled" : ""}><i class="bi bi-chevron-left"></i></button>
        <span class="btn btn-sm btn-outline-secondary disabled">Page ${this.page} / ${pages}</span>
        <button class="btn btn-sm btn-outline-secondary" data-next ${this.page >= pages ? "disabled" : ""}><i class="bi bi-chevron-right"></i></button></div>`;
      p.querySelector("[data-prev]").onclick = () => { this.page--; this.reload(); };
      p.querySelector("[data-next]").onclick = () => { this.page++; this.reload(); };
    }

    async edit(row) {
      const c = this.cfg;
      const fields = typeof c.fields === "function" ? c.fields(row) : c.fields;
      const values = row ? { ...(c.toForm ? c.toForm(row) : row) } : { ...(typeof c.defaults === "function" ? c.defaults() : c.defaults || {}) };
      await UI.formModal({
        title: row ? `Edit ${c.singular || "record"}` : `Add ${c.singular || "record"}`, fields, values,
        submitText: row ? "Save changes" : "Create", size: c.modalSize || "lg",
        onSubmit: async (vals) => {
          const data = c.toSave ? c.toSave(vals, row) : vals;
          const extra = c.toParams ? c.toParams(vals, row) : {};
          const r = await API.call("crud.save", { table: c.table, id: row?.id, data, ...(c.extraParams || {}), ...extra });
          UI.toast(r.message);
          App.clearLookup();
          if (c.afterSave) await c.afterSave(r.row, !row, vals);
          this.reload();
          return r.row;
        },
      });
    }

    async remove(row) {
      const name = this.cfg.nameOf ? this.cfg.nameOf(row) : (row.name || row.title || row.full_name || "this item");
      const ok = await UI.confirm(`"${UI.stripHtml(name).slice(0, 80)}" will be permanently deleted.${this.cfg.deleteWarning ? "\n" + this.cfg.deleteWarning : ""}`, { title: "Delete?", confirmText: "Yes, delete", danger: true });
      if (!ok) return;
      const r = await UI.run(() => API.call("crud.delete", { table: this.cfg.table, id: row.id }), { loading: "Deleting…" });
      if (r) { App.clearLookup(); this.reload(); }
    }
  }

  window.CrudPage = CrudPage;
})();
