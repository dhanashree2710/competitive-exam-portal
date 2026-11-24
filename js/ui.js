/* =====================================================================
   ui.js – friendly pop-ups, toasts, loading overlay, form modals, helpers
   Uses SweetAlert2 (CDN) with a plain fallback.
   ===================================================================== */
(function () {
  const hasSwal = () => typeof window.Swal !== "undefined";
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const TZ = "Asia/Kolkata";

  const Toast = () => Swal.mixin({ toast: true, position: "top-end", showConfirmButton: false, timer: 3000, timerProgressBar: true });

  const UI = {
    esc,

    // ---------- pop-ups ----------
    success(message, title = "Success") { return this._alert("success", title, message); },
    error(message, title = "Oops!") { return this._alert("error", title, message); },
    warn(message, title = "Please check") { return this._alert("warning", title, message); },
    info(message, title = "Information") { return this._alert("info", title, message); },
    _alert(icon, title, message) {
      if (!hasSwal()) { window.alert(`${title}\n\n${message}`); return Promise.resolve(); }
      return Swal.fire({ icon, title, text: message, confirmButtonColor: "#115e59", confirmButtonText: "OK" });
    },
    toast(message, icon = "success") {
      if (!message) return;
      if (!hasSwal()) { console.log(message); return; }
      Toast().fire({ icon, title: message });
    },
    async confirm(message, { title = "Are you sure?", confirmText = "Yes, continue", cancelText = "Cancel", danger = false, icon } = {}) {
      if (!hasSwal()) return window.confirm(`${title}\n\n${message}`);
      const r = await Swal.fire({
        icon: icon || (danger ? "warning" : "question"), title, html: esc(message).replace(/\n/g, "<br>"),
        showCancelButton: true, confirmButtonText: confirmText, cancelButtonText: cancelText,
        confirmButtonColor: danger ? "#dc3545" : "#115e59", reverseButtons: true, focusCancel: danger,
      });
      return r.isConfirmed;
    },
    async prompt(title, { label = "", value = "", input = "text", placeholder = "", required = true } = {}) {
      if (!hasSwal()) { const v = window.prompt(title, value); return v === null ? null : v; }
      const r = await Swal.fire({
        title, input, inputLabel: label, inputValue: value, inputPlaceholder: placeholder, showCancelButton: true,
        confirmButtonColor: "#115e59", inputValidator: (v) => (required && !String(v).trim() ? "This field is required." : undefined),
      });
      return r.isConfirmed ? r.value : null;
    },

    // ---------- loading ----------
    loading(on, text = "Please wait…") {
      let el = document.getElementById("loadingOverlay");
      if (!el) {
        el = document.createElement("div");
        el.id = "loadingOverlay"; el.className = "loading-overlay";
        el.innerHTML = `<div class="loader-ring" role="status"></div><div class="fw-semibold text-secondary" id="loadingText"></div>`;
        document.body.appendChild(el);
      }
      el.querySelector("#loadingText").textContent = text;
      el.classList.toggle("show", !!on);
    },

    /** Show any error in plain words. Raw technical errors are never shown. */
    handle(err) {
      if (!err) return;
      if (err.silent) return;
      if (err.name === "ApiError") return this.error(err.message);
      console.error(err);
      return this.error("Something unexpected happened. Please refresh the page and try again.");
    },

    /** Run an async task with loading overlay, success toast and friendly error. */
    async run(fn, { loading = "Please wait…", success, quiet = false } = {}) {
      try {
        if (loading) this.loading(true, loading);
        const r = await fn();
        this.loading(false);
        const msg = success === false ? null : (success || r?.message);
        if (msg && !quiet) this.toast(msg);
        return r ?? true;
      } catch (e) {
        this.loading(false);
        this.handle(e);
        return null;
      }
    },

    // ---------- formatting ----------
    fmtDate(v) { if (!v) return "—"; const d = new Date(v); return isNaN(d) ? "—" : d.toLocaleDateString("en-IN", { timeZone: TZ, day: "2-digit", month: "short", year: "numeric" }); },
    fmtDateTime(v) { if (!v) return "—"; const d = new Date(v); return isNaN(d) ? "—" : d.toLocaleString("en-IN", { timeZone: TZ, day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }); },
    timeAgo(v) {
      if (!v) return ""; const s = Math.floor((Date.now() - new Date(v)) / 1000);
      if (s < 60) return "just now"; if (s < 3600) return `${Math.floor(s / 60)} min ago`; if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
      if (s < 604800) return `${Math.floor(s / 86400)} d ago`; return this.fmtDate(v);
    },
    duration(sec) { if (sec == null) return "—"; sec = Math.max(0, Math.round(sec)); const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60; return h ? `${h}h ${m}m` : m ? `${m}m ${s}s` : `${s}s`; },
    num(v, d = 2) { if (v === null || v === undefined || v === "") return "—"; const n = Number(v); return isNaN(n) ? "—" : String(Math.round(n * 10 ** d) / 10 ** d); },
    /** ISO -> value for <input type=datetime-local> in the browser's local time */
    toLocalInput(iso) { if (!iso) return ""; const d = new Date(iso); if (isNaN(d)) return ""; const p = (n) => String(n).padStart(2, "0"); return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`; },
    fromLocalInput(v) { if (!v) return null; const d = new Date(v); return isNaN(d) ? null : d.toISOString(); },
    roleLabel(r) { return ({ super_admin: "Super Admin", college_admin: "College Admin", institute_admin: "Institute Admin", faculty: "Faculty", student: "Student" })[r] || r || "—"; },
    initials(name) { return String(name || "?").split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join(""); },
    badge(status) {
      const map = {
        draft: "secondary", scheduled: "info", live: "success", completed: "dark", archived: "secondary", published: "success", closed: "dark",
        under_review: "warning", approved: "success", rejected: "danger", in_progress: "warning", submitted: "primary", auto_submitted: "primary",
        evaluated: "success", cancelled: "secondary", late: "warning", returned: "info", needs_correction: "danger", resubmitted: "primary",
        active: "success", inactive: "secondary", open: "success", upcoming: "info", attempted: "secondary", in_review: "warning",
        pending_work: "warning", reminder: "info", easy: "success", medium: "warning", hard: "danger", high: "danger", normal: "secondary", low: "light", urgent: "danger",
      };
      const s = String(status ?? "—");
      return `<span class="badge text-bg-${map[s] || "secondary"} text-capitalize">${esc(s.replace(/_/g, " "))}</span>`;
    },
    activeBadge(v) { return v === false ? '<span class="badge text-bg-secondary">Inactive</span>' : '<span class="badge text-bg-success">Active</span>'; },
    empty(text = "Nothing here yet.", icon = "inbox") { return `<div class="empty-state"><i class="bi bi-${icon}"></i>${esc(text)}</div>`; },
    qs(name) { return new URLSearchParams(location.search).get(name); },
    debounce(fn, ms = 350) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; },
    /** Render teacher-written question text safely (limited formatting + https images). */
    safeHtml(s) {
      const str = String(s ?? "");
      if (!/<[a-z][\s\S]*>/i.test(str)) return esc(str);
      const ALLOWED = new Set(["B", "I", "U", "STRONG", "EM", "BR", "P", "SUB", "SUP", "UL", "OL", "LI", "CODE", "PRE", "IMG", "TABLE", "THEAD", "TBODY", "TR", "TD", "TH", "SPAN", "DIV", "H5", "H6", "BLOCKQUOTE"]);
      const doc = new DOMParser().parseFromString(`<div>${str}</div>`, "text/html");
      const walk = (node) => {
        [...node.childNodes].forEach((n) => {
          if (n.nodeType === 1) {
            if (!ALLOWED.has(n.tagName)) { n.replaceWith(document.createTextNode(n.textContent)); return; }
            [...n.attributes].forEach((a) => { const keep = n.tagName === "IMG" && (a.name === "src" ? /^https:\/\//i.test(a.value) : a.name === "alt"); if (!keep) n.removeAttribute(a.name); });
            if (n.tagName === "IMG" && !n.getAttribute("src")) { n.remove(); return; }
            walk(n);
          } else if (n.nodeType !== 3) n.remove();
        });
      };
      const root = doc.body.firstChild; walk(root);
      return root.innerHTML;
    },
    stripHtml(s) { const d = document.createElement("div"); d.innerHTML = String(s ?? ""); return d.textContent || ""; },

    // ---------- generic modal ----------
    modal({ title, body = "", size = "", footer = null, static: isStatic = false }) {
      const el = document.createElement("div");
      el.className = "modal fade"; el.tabIndex = -1;
      el.innerHTML = `<div class="modal-dialog modal-dialog-scrollable ${size ? "modal-" + size : ""}"><div class="modal-content">
        <div class="modal-header"><h5 class="modal-title">${esc(title)}</h5><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
        <div class="modal-body"></div>
        ${footer === false ? "" : `<div class="modal-footer">${footer ?? '<button class="btn btn-light" data-bs-dismiss="modal">Close</button>'}</div>`}
      </div></div>`;
      const b = el.querySelector(".modal-body");
      if (typeof body === "string") b.innerHTML = body; else b.appendChild(body);
      document.body.appendChild(el);
      const bs = new bootstrap.Modal(el, isStatic ? { backdrop: "static", keyboard: false } : {});
      el.addEventListener("hidden.bs.modal", () => { bs.dispose(); el.remove(); });
      bs.show();
      return { el, body: b, close: () => bs.hide(), bs };
    },

    /**
     * Form modal. fields: [{name,label,type,required,options,placeholder,help,col,min,max,step,rows,
     *   watch:[fieldNames], visible:(values)=>bool, default}]
     * options may be an array [{value,label}] / strings or async (values) => array.
     * Resolves with values object or null when cancelled. onSubmit(values) may return a promise;
     * if it throws, the error is shown and the modal stays open.
     */
    formModal({ title, fields, values = {}, submitText = "Save", size = "lg", onSubmit }) {
      return new Promise((resolve) => {
        const form = document.createElement("form");
        form.noValidate = true;
        form.className = "row g-3";
        const m = this.modal({ title, body: form, size, footer: `<button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancel</button><button type="button" class="btn btn-primary" data-submit>${esc(submitText)}</button>`, static: true });
        let done = false;
        const getValues = () => UI.readForm(form, fields);
        const renderField = (f) => {
          if (f.type === "section") {            // a heading that splits a long form into parts
            const sec = document.createElement("div"); sec.className = "col-12"; sec.dataset.field = f.name;
            sec.innerHTML = `<div class="form-section">${f.icon ? `<i class="bi bi-${esc(f.icon)}"></i>` : ""}<span>${esc(f.label)}</span></div>`;
            form.appendChild(sec); return sec;
          }
          const id = "f_" + f.name + "_" + Math.random().toString(36).slice(2, 7);
          const v = values[f.name] ?? f.default ?? "";
          const col = document.createElement("div");
          col.className = f.col || (["textarea", "html", "options"].includes(f.type) ? "col-12" : "col-md-6");
          col.dataset.field = f.name;
          const req = f.required ? "required" : "";
          const lbl = f.label ? `<label class="form-label ${req}" for="${id}">${esc(f.label)}</label>` : "";
          const help = f.help ? `<div class="form-text">${f.help}</div>` : "";
          const common = `id="${id}" name="${f.name}" ${f.required ? "required" : ""} ${f.placeholder ? `placeholder="${esc(f.placeholder)}"` : ""} ${f.disabled ? "disabled" : ""}`;
          let input = "";
          switch (f.type) {
            case "textarea": input = `<textarea class="form-control" rows="${f.rows || 3}" ${common}>${esc(v)}</textarea>`; break;
            case "select": input = `<select class="form-select" ${common}><option value="">${esc(f.placeholder || "— Select —")}</option></select>`; break;
            case "multiselect": input = `<select class="form-select" multiple size="${f.size || 6}" ${common}></select><div class="form-text">Hold Ctrl (or Cmd) to select several.</div>`; break;
            case "checkbox": input = `<div class="form-check form-switch mt-md-4"><input class="form-check-input" type="checkbox" ${common} ${v === true || v === "true" ? "checked" : ""}><label class="form-check-label" for="${id}">${esc(f.checkLabel || f.label)}</label></div>`; break;
            case "datetime": input = `<input type="datetime-local" class="form-control" ${common} value="${esc(UI.toLocalInput(v))}">`; break;
            case "date": input = `<input type="date" class="form-control" ${common} value="${esc(String(v || "").slice(0, 10))}">`; break;
            case "number": input = `<input type="number" class="form-control" ${common} value="${esc(v)}" ${f.min !== undefined ? `min="${f.min}"` : ""} ${f.max !== undefined ? `max="${f.max}"` : ""} step="${f.step || "any"}">`; break;
            case "color": input = `<input type="color" class="form-control form-control-color" ${common} value="${esc(v || "#115e59")}">`; break;
            case "html": input = `<div id="${id}"></div>`; break;
            case "upload": input = UI._uploadFieldHtml(f, id, v); break;
            default: input = `<input type="${f.type || "text"}" class="form-control" ${common} value="${esc(v)}" ${f.type === "password" ? 'autocomplete="new-password"' : ""}>`;
          }
          col.innerHTML = (f.type === "checkbox" ? "" : lbl) + input + help + `<div class="invalid-feedback"></div>`;
          form.appendChild(col);
          if (f.type === "html" && f.render) f.render(col.querySelector(`#${id}`), values, form);
          if (f.type === "upload") UI._bindUploadField(col, f, form);
          return col;
        };
        fields.forEach(renderField);

        const loadOptions = async (f) => {
          if (!["select", "multiselect"].includes(f.type)) return;
          const sel = form.querySelector(`[name="${f.name}"]`);
          const current = sel.dataset.loaded ? (f.type === "multiselect" ? [...sel.selectedOptions].map((o) => o.value) : sel.value) : values[f.name];
          let opts = f.options || [];
          if (typeof opts === "function") {
            sel.disabled = true;
            try { opts = await opts(getValues()); } catch (e) { UI.handle(e); opts = []; }
            sel.disabled = !!f.disabled;
          }
          const cur = Array.isArray(current) ? current.map(String) : [String(current ?? "")];
          sel.innerHTML = (f.type === "select" ? `<option value="">${esc(f.placeholder || "— Select —")}</option>` : "") +
            opts.map((o) => { const val = typeof o === "object" ? o.value : o; const lab = typeof o === "object" ? o.label : o; return `<option value="${esc(val)}" ${cur.includes(String(val)) ? "selected" : ""}>${esc(lab)}</option>`; }).join("");
          sel.dataset.loaded = "1";
        };
        const applyVisibility = () => {
          const vals = getValues();
          fields.forEach((f) => { if (f.visible) form.querySelector(`[data-field="${f.name}"]`).classList.toggle("d-none", !f.visible(vals)); });
        };
        Promise.all(fields.map(loadOptions)).then(applyVisibility);
        // clear a field's error as soon as the user edits it
        form.addEventListener("input", (e) => {
          const wrap = e.target.closest("[data-field]");
          if (!wrap) return;
          e.target.classList.remove("is-invalid");
          const fb = wrap.querySelector(".invalid-feedback"); if (fb) fb.style.display = "";
        });
        form.addEventListener("change", (e) => {
          const name = e.target.name;
          fields.filter((f) => (f.watch || []).includes(name)).forEach(loadOptions);
          applyVisibility();
        });

        const submit = async () => {
          const vals = getValues();
          // validation
          let firstBad = null;
          form.querySelectorAll(".is-invalid").forEach((x) => x.classList.remove("is-invalid"));
          for (const f of fields) {
            const wrap = form.querySelector(`[data-field="${f.name}"]`);
            if (wrap.classList.contains("d-none")) continue;
            const input = wrap.querySelector("[name]");
            const v = vals[f.name];
            let msg = "";
            if (f.required && (v === null || v === "" || v === undefined || (Array.isArray(v) && !v.length))) msg = `${f.label || f.name} is required.`;
            else if (f.type === "email" && v && !/^\S+@\S+\.\S+$/.test(v)) msg = "Please enter a valid email address.";
            else if (f.type === "number" && v !== null && v !== "" && ((f.min !== undefined && v < f.min) || (f.max !== undefined && v > f.max))) msg = `Please enter a value${f.min !== undefined ? " from " + f.min : ""}${f.max !== undefined ? " to " + f.max : ""}.`;
            else if (f.validate) msg = f.validate(v, vals) || "";
            if (msg) {
              if (input) input.classList.add("is-invalid");
              wrap.querySelector(".invalid-feedback").textContent = msg;
              wrap.querySelector(".invalid-feedback").style.display = "block";
              firstBad = firstBad || input || wrap;
            } else if (wrap.querySelector(".invalid-feedback")) wrap.querySelector(".invalid-feedback").style.display = "";
          }
          if (firstBad) { firstBad.focus(); return; }
          const btn = m.el.querySelector("[data-submit]");
          if (onSubmit) {
            btn.disabled = true; const old = btn.innerHTML; btn.innerHTML = `<span class="spinner-border spinner-border-sm me-1"></span>Saving…`;
            try { const r = await onSubmit(vals); done = true; m.close(); resolve(r ?? vals); }
            catch (e) { UI.handle(e); }
            finally { btn.disabled = false; btn.innerHTML = old; }
          } else { done = true; m.close(); resolve(vals); }
        };
        m.el.querySelector("[data-submit]").addEventListener("click", submit);
        form.addEventListener("submit", (e) => { e.preventDefault(); submit(); });
        form.addEventListener("keydown", (e) => { if (e.key === "Enter" && e.target.tagName === "INPUT") { e.preventDefault(); submit(); } });
        m.el.addEventListener("hidden.bs.modal", () => { if (!done) resolve(null); });
      });
    },

    // ---------- file upload helpers ----------
    _uploadFieldHtml(f, id, v) {
      return `<input type="hidden" name="${f.name}" value="${esc(v)}">
        <div class="upload-box" data-upload>
          <div class="upload-preview" data-preview></div>
          <div class="d-flex flex-wrap gap-2 align-items-center">
            <label class="btn btn-outline-primary btn-sm mb-0"><i class="bi bi-cloud-arrow-up me-1"></i><span data-label>${v ? "Replace file" : (f.buttonText || "Upload file")}</span>
              <input type="file" hidden id="${id}" accept="${esc(f.accept || "")}"></label>
            <button type="button" class="btn btn-light btn-sm text-danger ${v ? "" : "d-none"}" data-clear><i class="bi bi-x-lg me-1"></i>Remove</button>
            <span class="small text-secondary">${esc(f.hint || "Max 10 MB")}</span>
          </div>
          <div class="progress mt-2 d-none" style="height:6px" data-progress><div class="progress-bar progress-bar-striped progress-bar-animated w-100"></div></div>
        </div>`;
    },
    _bindUploadField(col, f, form) {
      const hidden = col.querySelector(`input[type=hidden][name="${f.name}"]`);
      const box = col.querySelector("[data-upload]");
      const show = () => {
        const v = hidden.value;
        const isImg = /\.(png|jpe?g|gif|webp|svg)(\?|$)/i.test(v);
        box.querySelector("[data-preview]").innerHTML = !v ? "" : isImg && /^https?:/.test(v)
          ? `<img src="${esc(v)}" alt="" class="upload-thumb">`
          : `<a href="#" class="upload-file" data-open><i class="bi bi-file-earmark-check me-1"></i>${esc(form.querySelector(`[name="${f.nameField}"]`)?.value || v.split("/").pop().replace(/^[a-f0-9]{24}_/, ""))}</a>`;
        box.querySelector("[data-clear]").classList.toggle("d-none", !v);
        box.querySelector("[data-label]").textContent = v ? "Replace file" : (f.buttonText || "Upload file");
        box.querySelector("[data-open]")?.addEventListener("click", (e) => { e.preventDefault(); UI.openFile(v); });
      };
      col.querySelector("input[type=file]").addEventListener("change", async (e) => {
        const file = e.target.files[0]; e.target.value = "";
        if (!file) return;
        const prog = box.querySelector("[data-progress]"); prog.classList.remove("d-none");
        try {
          const r = await API.upload(file, f.purpose, typeof f.extra === "function" ? f.extra(form) : (f.extra || {}));
          hidden.value = f.store === "path" ? r.path : (r.url || r.path);
          if (f.nameField && form.querySelector(`[name="${f.nameField}"]`)) form.querySelector(`[name="${f.nameField}"]`).value = file.name;
          UI.toast("File uploaded.");
          if (f.onUpload) f.onUpload(r, form);
        } catch (err) { UI.handle(err); }
        finally { prog.classList.add("d-none"); show(); }
      });
      box.querySelector("[data-clear]").addEventListener("click", () => { hidden.value = ""; if (f.nameField && form.querySelector(`[name="${f.nameField}"]`)) form.querySelector(`[name="${f.nameField}"]`).value = ""; show(); });
      show();
    },
    /** Upload with a loading overlay; resolves with the upload result or null (error already shown). */
    async upload(file, purpose, extra = {}, label = "Uploading…") {
      return this.run(() => API.upload(file, purpose, extra), { loading: label, success: "File uploaded." });
    },
    /** Open a stored file (public link, or a short-lived private link). */
    async openFile(ref) {
      const url = await this.run(() => API.fileUrl(ref), { loading: "Opening file…", success: false });
      if (url) window.open(url, "_blank", "noopener");
    },
    /** Ask the user to pick a file; resolves with the File or null. */
    pickFile(accept = "") {
      return new Promise((resolve) => {
        const i = document.createElement("input"); i.type = "file"; i.accept = accept;
        i.onchange = () => resolve(i.files[0] || null); i.click();
      });
    },

    readForm(form, fields) {
      const out = {};
      for (const f of fields) {
        if (f.type === "section") continue;
        const el = form.querySelector(`[name="${f.name}"]`);
        if (f.type === "html") { out[f.name] = f.read ? f.read(form) : undefined; continue; }
        if (!el) continue;
        if (f.type === "checkbox") out[f.name] = el.checked;
        else if (f.type === "multiselect") out[f.name] = [...el.selectedOptions].map((o) => o.value);
        else if (f.type === "number") out[f.name] = el.value === "" ? null : Number(el.value);
        else if (f.type === "datetime") out[f.name] = UI.fromLocalInput(el.value);
        else out[f.name] = el.value.trim();
      }
      return out;
    },
  };

  window.UI = UI;
  // ripple effect on every button press
  document.addEventListener("pointerdown", (e) => {
    const b = e.target.closest(".btn"); if (!b || b.disabled) return;
    const r = b.getBoundingClientRect(); const span = document.createElement("span");
    span.className = "ripple"; span.style.left = `${e.clientX - r.left}px`; span.style.top = `${e.clientY - r.top}px`;
    b.appendChild(span); setTimeout(() => span.remove(), 650);
  });
  // last-resort guard: never show a blank page or a raw error
  window.addEventListener("unhandledrejection", (e) => { e.preventDefault(); UI.handle(e.reason); });
})();
