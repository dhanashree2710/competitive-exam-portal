App.init({ roles: ["super_admin"] }).then(async () => {
  const el = document.getElementById("app");
  const load = async () => {
    let s;
    try { s = await API.call("settings.get"); } catch (e) { el.innerHTML = UI.empty(e.message, "exclamation-circle"); return; }
    el.innerHTML = `<div class="page-head"><h1 class="page-title"><i class="bi bi-gear me-2 text-primary"></i>Settings</h1></div>
    <div class="row g-3 stagger"><div class="col-lg-7"><div class="card"><div class="card-header"><i class="bi bi-stars me-1 text-primary"></i>AI (Groq)</div><div class="card-body">
      <div class="d-flex gap-2 flex-wrap mb-3">
        <span class="badge text-bg-${s.groq_configured ? "success" : "warning"}"><i class="bi bi-${s.groq_configured ? "check2" : "exclamation-triangle"}"></i> API key ${s.groq_configured ? "saved " + UI.esc(s.groq_key_hint) : "not set"}</span>
        <span class="badge text-bg-${s.http_enabled ? "success" : "danger"}"><i class="bi bi-${s.http_enabled ? "check2" : "x"}"></i> AI connection ${s.http_enabled ? "on" : "off"}</span></div>
      ${s.http_enabled ? "" : `<div class="alert alert-warning small">The AI service connection isn't switched on yet, so AI features are unavailable.</div>`}
      <form id="f" novalidate>
        <label class="form-label">Groq API key</label>
        <input type="password" class="form-control mb-1" name="groq_api_key" placeholder="${s.groq_configured ? "Leave empty to keep the saved key" : "gsk_…"}" autocomplete="off">
        <div class="form-text mb-3">Stored privately on the server. It is never sent to browsers and never shown again. Get a key at console.groq.com.</div>
        <label class="form-label">Model</label>
        <input class="form-control mb-1" name="groq_model" value="${UI.esc(s.groq_model)}">
        <div class="form-text mb-3">Default <code>openai/gpt-oss-120b</code>. If it stops working, check console.groq.com/docs/models.</div>
        <div class="d-flex flex-wrap gap-2"><button class="btn btn-primary"><i class="bi bi-save me-1"></i>Save</button>
        <button type="button" class="btn btn-outline-primary" id="test"><i class="bi bi-lightning me-1"></i>Test AI</button>
        ${s.groq_configured ? `<button type="button" class="btn btn-outline-danger ms-auto" id="rm"><i class="bi bi-trash me-1"></i>Remove key</button>` : ""}</div>
      </form></div></div></div>
      <div class="col-lg-5"><div class="card"><div class="card-header"><i class="bi bi-shield-lock me-1 text-primary"></i>Security</div><div class="card-body small">
        <ul class="mb-0 ps-3"><li class="mb-2">All tables are locked. The browser can only use the portal's secure server functions.</li>
        <li class="mb-2">Passwords are hashed with bcrypt. Accounts lock for 15 minutes after 5 wrong passwords.</li>
        <li class="mb-2">Answer keys never reach the student's browser. Scoring happens on the server.</li>
        <li>Files are in a private bucket. Downloads use 10-minute links.</li></ul></div></div></div></div>`;
    el.querySelector("#f").onsubmit = async (e) => {
      e.preventDefault();
      const v = Object.fromEntries(new FormData(e.target));
      if (v.groq_api_key && !/^gsk_[A-Za-z0-9]{20,}$/.test(v.groq_api_key.trim())) return UI.warn("That doesn't look like a Groq key. It should start with “gsk_”.");
      if (await UI.run(() => API.call("settings.save", v))) load();
    };
    el.querySelector("#test").onclick = async () => { const r = await UI.run(() => API.call("settings.testAI"), { loading: "Contacting Groq…", quiet: true }); if (r) UI.success(r.message); };
    el.querySelector("#rm")?.addEventListener("click", async () => { if (await UI.confirm("AI features will stop working until a new key is saved.", { title: "Remove the Groq key?", confirmText: "Remove", danger: true })) { if (await UI.run(() => API.call("settings.save", { remove_key: true }))) load(); } });
  };
  load();
});
