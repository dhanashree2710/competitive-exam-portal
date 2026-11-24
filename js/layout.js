/* =====================================================================
   layout.js – auth guard + sidebar/topbar shell for every inner page.
   Usage in a page:  App.init({ roles: ["super_admin", ...] }).then(user => { ... })
   ===================================================================== */
(function () {
  const ADMIN = ["super_admin", "college_admin", "institute_admin"];
  const STAFF = [...ADMIN, "faculty"];
  // ---------- navigation drawer: a short list per role (profile & notifications live in the top bar) ----------
  const L = (href, icon, label) => ({ href, icon, label });
  const S = (title, items) => ({ title, items });
  function menuFor(role) {
    const home = S("", [L("dashboard.html", "grid-1x2", "Dashboard")]);
    const exams = S("Exams", [L("exams.html", "card-checklist", "Exams"), L("results.html", "trophy", "Results")]);
    const learn = S("Learning", [L("assignments.html", "journal-check", "Assignments"), L("activities.html", "lightning-charge", "Activities")]);
    const track = S("Monitoring", [L("engagement.html", "speedometer", "Engagement"), L("insights.html", "graph-up-arrow", "Insights"), L("reports.html", "file-earmark-bar-graph", "Reports")]);
    const news = S("", [L("announcements.html", "megaphone", "Announcements")]);
    if (role === "super_admin") return [home,
      S("Platform", [L("organizations.html", "building", "Organizations"), L("users.html", "people", "Users"), L("students.html", "mortarboard", "Students"), L("data-export.html", "cloud-arrow-down", "Data export"), L("settings.html", "gear", "Settings"), L("audit.html", "shield-check", "Audit log")]),
      S("Academics", [L("syllabus.html", "diagram-3", "Syllabus"), L("batches.html", "collection", "Batches"), L("questions.html", "patch-question", "Questions")]),
      exams, learn, track, news];
    if (role === "college_admin") return [home,
      S("College", [L("organizations.html", "buildings", "Institutes"), L("users.html", "people", "Users"), L("students.html", "mortarboard", "Students")]),
      S("Academics", [L("syllabus.html", "diagram-3", "Syllabus"), L("batches.html", "collection", "Batches"), L("questions.html", "patch-question", "Questions")]),
      exams, learn, track, news];
    if (role === "institute_admin") return [home,
      S("Institute", [L("students.html", "mortarboard", "Students"), L("users.html", "people", "Users"), L("batches.html", "collection", "Batches"), L("syllabus.html", "diagram-3", "Syllabus"), L("questions.html", "patch-question", "Questions")]),
      exams, learn, track, news];
    if (role === "faculty") return [home,
      S("Teaching", [L("students.html", "mortarboard", "My students"), L("questions.html", "patch-question", "Questions"), L("syllabus.html", "diagram-3", "Syllabus"), L("batches.html", "collection", "My batches")]),
      exams, learn, track, news];
    return [home,
      S("My work", [L("my-exams.html", "pencil-square", "My exams"), L("results.html", "trophy", "My results"), L("my-assignments.html", "journal-check", "Assignments"), L("activities.html", "lightning-charge", "Activities")]),
      S("My growth", [L("insights.html", "graph-up-arrow", "Progress & plan"), L("reports.html", "file-earmark-arrow-down", "Reports")]),
      news];
  }
  // pages that are not in the menu highlight their parent entry
  const PARENT = { "exam-edit.html": "exams.html", "exam-wizard.html": "exams.html", "batch-view.html": "batches.html", "result-view.html": "results.html", "exam-take.html": "my-exams.html", "notifications.html": "", "profile.html": "" };


  const App = {
    user: null, ADMIN, STAFF,
    is(...roles) { return !!this.user && roles.flat().includes(this.user.role); },
    isStaff() { return this.is(STAFF); },
    isAdmin() { return this.is(ADMIN); },

    async init({ roles = null, bare = false } = {}) {
      if (!API.token) { location.replace("../login.html"); return new Promise(() => {}); }
      if (!document.querySelector(".page-loader")) { const pl = document.createElement("div"); pl.className = "page-loader"; document.body.appendChild(pl); setTimeout(() => pl.remove(), 1300); }
      const cached = API.cachedUser();
      if (cached && !bare) this.render(cached, 0);
      let me;
      try { me = await API.call("auth.me"); }
      catch (e) {
        if (e.silent) return new Promise(() => {});
        document.getElementById("app")?.classList.remove("d-none");
        await UI.handle(e);
        return new Promise(() => {});
      }
      this.user = me.user; this.me = me; API.setUser(me.user);
      setTimeout(() => this.checkBackend(me), 50);
      if (roles && !roles.includes(me.user.role)) {
        await UI.warn("You don't have access to this page. Taking you to your dashboard.", "Access denied");
        location.replace("dashboard.html");
        return new Promise(() => {});
      }
      if (!bare) this.render(me.user, me.unread);
      document.getElementById("app")?.classList.remove("d-none");
      return me.user;
    },

    render(user, unread) {
      const page = location.pathname.split("/").pop() || "dashboard.html";
      const C = window.APP_CONFIG || {};
      const groups = menuFor(user.role);
      const cur = PARENT[page] || page;
      const nav = `<div class="side-user"><span class="avatar">${user.avatar_url ? `<img src="${UI.esc(user.avatar_url)}" alt="">` : UI.esc(UI.initials(user.full_name))}</span>
          <div class="min-w-0"><div class="text-truncate">${UI.esc(user.full_name || "")}</div><small>${UI.esc(UI.roleLabel(user.role))}</small></div></div>` +
        groups.map((g) => `${g.title ? `<div class="side-cap">${UI.esc(g.title)}</div>` : `<div class="side-gap"></div>`}` +
          g.items.map((n) => `<a class="side-link ${cur === n.href ? "active" : ""}" href="${n.href}" title="${UI.esc(n.label)}"><i class="bi bi-${n.icon}"></i><span>${UI.esc(n.label)}</span></a>`).join("")).join("");
      const avatar = user.avatar_url ? `<img src="${UI.esc(user.avatar_url)}" alt="">` : UI.esc(UI.initials(user.full_name));
      let shell = document.getElementById("appShell");
      if (!shell) {
        shell = document.createElement("div");
        shell.id = "appShell"; shell.className = "app-shell";
        shell.innerHTML = `
          <aside class="app-sidebar offcanvas-lg offcanvas-start" tabindex="-1" id="sidebar">
            <div class="d-flex align-items-center justify-content-between">
              <a class="brand" href="dashboard.html"><span class="logo"><i class="bi bi-mortarboard-fill"></i></span><span class="brand-text">${UI.esc(C.APP_NAME || "KDRT ExamSphere")}</span></a>
              <button type="button" class="side-toggle d-none d-lg-grid" id="miniBtn" title="Collapse menu" aria-label="Collapse menu"><i class="bi bi-chevron-double-left"></i></button>
              <button type="button" class="btn-close btn-close-white d-lg-none me-3" data-bs-dismiss="offcanvas" data-bs-target="#sidebar" aria-label="Close"></button>
            </div>
            <nav class="nav flex-column pb-2" id="sideNav"></nav>
          </aside>
          <div class="app-main">
            <header class="app-topbar">
              <button class="btn btn-light d-lg-none" data-bs-toggle="offcanvas" data-bs-target="#sidebar" aria-label="Menu"><i class="bi bi-list"></i></button>
              <div class="fw-semibold text-truncate" id="orgName"></div>
              <div class="ms-auto d-flex align-items-center gap-2">
                <a href="notifications.html" class="btn btn-light position-relative" title="Notifications"><i class="bi bi-bell"></i><span class="badge rounded-pill text-bg-danger bell-badge d-none" id="bellCount"></span></a>
                <div class="dropdown">
                  <button class="btn btn-light d-flex align-items-center gap-2" data-bs-toggle="dropdown">
                    <span class="avatar" id="topAvatar"></span>
                    <span class="d-none d-sm-inline text-start lh-sm"><span class="d-block fw-semibold small" id="topName"></span><span class="d-block text-secondary" style="font-size:.72rem" id="topRole"></span></span>
                  </button>
                  <ul class="dropdown-menu dropdown-menu-end">
                    <li><a class="dropdown-item" href="profile.html"><i class="bi bi-person me-2"></i>My profile</a></li>
                    <li><hr class="dropdown-divider"></li>
                    <li><button class="dropdown-item text-danger" id="logoutBtn"><i class="bi bi-box-arrow-right me-2"></i>Sign out</button></li>
                  </ul>
                </div>
              </div>
            </header>
            <div class="page-bar">
              <button type="button" class="pb-btn" id="backBtn" title="Go back"><i class="bi bi-arrow-left"></i><span>Back</span></button>
              <button type="button" class="pb-btn" id="refreshBtn" title="Reload this page"><i class="bi bi-arrow-clockwise"></i><span>Refresh</span></button>
              <nav class="pb-crumbs" id="crumbs" aria-label="breadcrumb"></nav>
            </div>
            <main class="app-content" id="mainContent"></main>
          </div>`;
        document.body.prepend(shell);
        const app = document.getElementById("app");
        if (app) { app.classList.add("anim-in"); shell.querySelector("#mainContent").appendChild(app); }
        shell.querySelector("#logoutBtn").addEventListener("click", () => this.logout());
        shell.querySelector("#backBtn").addEventListener("click", () => this.back());
        // slim icon-only menu on desktop (remembered on this device)
        // minimal by default: an icon rail that opens over the page on hover; the pin keeps it open
        const setMini = (on) => { document.body.classList.toggle("side-mini", on); const b = shell.querySelector("#miniBtn"); b.title = on ? "Keep menu open" : "Make menu minimal";
          b.innerHTML = `<i class="bi bi-${on ? "pin-angle" : "chevron-double-left"}"></i>`; try { localStorage.setItem("ep_side_mini", on ? "1" : "0"); } catch { /* ignore */ } };
        let mini = true; try { mini = localStorage.getItem("ep_side_mini") !== "0"; } catch { /* ignore */ }
        setMini(mini);
        shell.querySelector("#miniBtn").addEventListener("click", () => setMini(!document.body.classList.contains("side-mini")));
        // phones: close the drawer after picking a page
        shell.querySelector("#sideNav").addEventListener("click", (e) => { if (e.target.closest(".side-link") && window.innerWidth < 992) bootstrap.Offcanvas.getInstance(shell.querySelector("#sidebar"))?.hide(); });
        shell.querySelector("#refreshBtn").addEventListener("click", (ev) => { ev.currentTarget.querySelector("i").classList.add("spin"); this.clearLookup(); location.reload(); });
      }
      const sideNav = shell.querySelector("#sideNav");
      sideNav.innerHTML = nav;
      const item = groups.flatMap((g) => g.items.map((i) => ({ ...i, group: g.title }))).find((i) => i.href === page) ||
                   { label: document.title.split("·")[0].trim(), group: "" };
      shell.querySelector("#crumbs").innerHTML = page === "dashboard.html" ? `<span class="pb-here"><i class="bi bi-grid-1x2 me-1"></i>Dashboard</span>`
        : `<a href="dashboard.html">Dashboard</a>${item.group ? `<i class="bi bi-chevron-right"></i><span>${UI.esc(item.group)}</span>` : ""}<i class="bi bi-chevron-right"></i><span class="pb-here">${UI.esc(item.label)}</span>`;
      const stack = this.trackPage();
      shell.querySelector("#backBtn").classList.toggle("invisible", stack.length <= 1 && page === "dashboard.html");
      if (stack.length > 1) shell.querySelector("#backBtn").title = "Back to " + (stack[stack.length - 2].split("?")[0].replace(".html", "").replace(/-/g, " "));
      shell.querySelector("#topAvatar").innerHTML = avatar;
      shell.querySelector("#topName").textContent = user.full_name || user.email;
      shell.querySelector("#topRole").textContent = UI.roleLabel(user.role);
      shell.querySelector("#orgName").textContent = user.organization?.name || (user.role === "super_admin" ? "All organizations" : "");
      this.setUnread(unread);
    },

    /** Warn when the database still runs an older backend than this website needs. */
    BACKEND_VERSION: "3.4",
    checkBackend(me) {
      // silent: only a note for developers in the browser console
      if (!me || me.backend_version !== this.BACKEND_VERSION) console.warn("KDRT ExamSphere: server version", me && me.backend_version, "expected", this.BACKEND_VERSION);
    },

    setUnread(n) {
      const b = document.getElementById("bellCount");
      if (!b) return;
      b.textContent = n > 99 ? "99+" : n;
      b.classList.toggle("d-none", !n);
    },

    /** Back: previous page inside the portal, otherwise the dashboard. */
    /** Pages visited in this tab (kept by the portal itself, so Back works even when the server hides the referrer). */
    navStack() { try { return JSON.parse(sessionStorage.getItem("ep_nav") || "[]"); } catch { return []; } },
    trackPage() {
      const here = location.pathname.split("/").pop() + location.search;
      let st = this.navStack();
      let wentBack = false; try { wentBack = sessionStorage.getItem("ep_nav_back") === "1"; sessionStorage.removeItem("ep_nav_back"); } catch { /* ignore */ }
      if (wentBack) { const i = st.lastIndexOf(here); st = i >= 0 ? st.slice(0, i + 1) : [...st, here]; }
      else if (st[st.length - 1] !== here) st.push(here);
      try { sessionStorage.setItem("ep_nav", JSON.stringify(st.slice(-30))); } catch { /* ignore */ }
      return st;
    },
    back() {
      const st = this.navStack();
      const prev = st.length > 1 ? st[st.length - 2] : null;
      if (prev) { try { sessionStorage.setItem("ep_nav_back", "1"); } catch { /* ignore */ } location.href = prev; }
      else if (location.pathname.split("/").pop() !== "dashboard.html") location.href = "dashboard.html";
    },

    async logout() {
      if (!(await UI.confirm("You will need to sign in again to continue.", { title: "Sign out?", confirmText: "Sign out" }))) return;
      try { await API.call("auth.logout", {}, { noRedirect: true }); } catch { /* ignore */ }
      API.clear();
      location.replace("../login.html?logout=1");
    },

    /** cached dropdown lookups */
    _cache: {},
    async lookup(type, params = {}) {
      const key = type + JSON.stringify(params);
      if (!this._cache[key]) this._cache[key] = API.call("lookup", { type, ...params }).then((r) => r.rows).catch((e) => { delete this._cache[key]; throw e; });
      return this._cache[key];
    },
    clearLookup() { this._cache = {}; },
    async options(type, params = {}, labelFn = (r) => r.name) {
      return (await this.lookup(type, params)).map((r) => ({ value: r.id, label: labelFn(r) }));
    },
  };

  window.App = App;
})();
