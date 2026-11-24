/* =====================================================================
   api.js – talks directly to Supabase:
     • POST /rest/v1/rpc/api      (one secure database function, see sql/01_setup_all.sql)
     • Supabase Storage           (uploads/downloads allowed only with a ticket from the api)
   Nothing to deploy – only the public anon key is used in the browser.
   ===================================================================== */
(function () {
  const C = window.APP_CONFIG || {};
  const BASE = (C.SUPABASE_URL || "").replace(/\/$/, "");
  const TOKEN_KEY = "ep_token";
  const USER_KEY = "ep_user";

  const mem = {};
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return mem[k] ?? null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { mem[k] = v; } },
    del(k) { try { localStorage.removeItem(k); } catch { delete mem[k]; } },
  };

  class ApiError extends Error {
    constructor(message, status = 0, silent = false) { super(message); this.name = "ApiError"; this.status = status; this.silent = silent; }
  }

  const configured = () => BASE && C.SUPABASE_ANON_KEY && !/YOUR-/.test(BASE + C.SUPABASE_ANON_KEY);
  const loginPage = () => (location.pathname.includes("/pages/") ? "../" : "") + "login.html";

  async function request(url, opts, what = "request") {
    if (!configured()) throw new ApiError("This website isn't linked to the exam server yet. Administrator: please upload the file js/config.js (it holds your Supabase address and public key) to the server.");
    try { return await fetch(url, opts); }
    catch {
      throw new ApiError(navigator.onLine === false
        ? "You appear to be offline. Please check your internet connection and try again."
        : "Couldn't connect to the server. Please check your internet connection and try again.");
    }
  }

  const API = {
    ApiError,
    get token() {
      // "Remember me" was not ticked: the sign-in lasts only until the browser is closed
      try { if (store.get("ep_session_only") && !sessionStorage.getItem("ep_alive")) { store.del(TOKEN_KEY); store.del(USER_KEY); store.del("ep_session_only"); } } catch { /* ignore */ }
      return store.get(TOKEN_KEY) || "";
    },
    setSession(token, user) { store.set(TOKEN_KEY, token); store.set(USER_KEY, JSON.stringify(user || {})); },
    setUser(user) { store.set(USER_KEY, JSON.stringify(user || {})); },
    cachedUser() { try { return JSON.parse(store.get(USER_KEY) || "null"); } catch { return null; } },
    clear() { store.del(TOKEN_KEY); store.del(USER_KEY); },
    headers(json = true) {
      const h = { apikey: C.SUPABASE_ANON_KEY, Authorization: `Bearer ${C.SUPABASE_ANON_KEY}` };
      if (json) h["Content-Type"] = "application/json";
      return h;
    },

    /** Call one action of the database API. Resolves with the response object, rejects with ApiError (friendly text). */
    async call(action, params = {}, opts = {}) {
      const res = await request(`${BASE}/rest/v1/rpc/api`, {
        method: "POST", headers: this.headers(),
        body: JSON.stringify({ p_action: action, p_params: { ...params, user_agent: navigator.userAgent.slice(0, 200) }, p_token: this.token || null }),
      });
      let body = null;
      try { body = await res.json(); } catch { /* not json */ }
      if (!res.ok) {
        const code = body && (body.code || "");
        let msg;
        if (res.status === 404 || code === "PGRST202") msg = "This service isn't available right now. Please try again later or contact your administrator.";
        else if (res.status === 401 || res.status === 403) msg = "The portal couldn't connect securely. Please contact your administrator.";
        else if (code === "57014") msg = "The server took too long to answer. Please try again.";
        else if (res.status >= 500) msg = "The server is having a problem right now. Please try again in a moment.";
        else msg = "The request couldn't be completed. Please refresh the page and try again.";
        throw new ApiError(msg, res.status);
      }
      if (!body || body.ok !== true) {
        if (body && body.code === "AUTH") {
          this.clear();
          if (!opts.noRedirect) { location.href = loginPage() + "?expired=1"; throw new ApiError(body.error, 401, true); }
          throw new ApiError(body.error, 401);
        }
        throw new ApiError((body && body.error) || "Something went wrong. Please try again.", Number(body && body.code) || 400);
      }
      return body;
    },

    /**
     * Upload a file to Supabase Storage.
     * purpose → bucket: submission→student-submissions, assignment→assignment-attachments, assignment_file→assignment-files,
     * question_image→question-images, question_media→question-media, avatar/logo→avatars, announcement→announcements-media,
     * syllabus→syllabus-files, scorecard→scorecards, document→uploads.
     * Resolves with { path, url, name, size, type, bucket, public }. "path" is what gets stored in the database;
     * "url" is a permanent link for public buckets (images shown in pages).
     */
    async upload(file, purpose, extra = {}) {
      if (!file) throw new ApiError("Please choose a file to upload.");
      if (file.size > 10 * 1024 * 1024) throw new ApiError("The file is too large. The maximum size is 10 MB.");
      if (!file.size) throw new ApiError("This file is empty. Please choose another file.");
      const t = await this.call("files.prepareUpload", { purpose, name: file.name, size: file.size, ...extra });
      const objPath = t.name.split("/").map(encodeURIComponent).join("/");
      const res = await request(`${BASE}/storage/v1/object/${t.bucket}/${objPath}`, {
        method: "POST", headers: { ...this.headers(false), "Content-Type": file.type || "application/octet-stream", "x-upsert": "false", "cache-control": "3600" }, body: file,
      }, "upload");
      if (!res.ok) {
        let b = null; try { b = await res.json(); } catch { /* ignore */ }
        const m = String((b && (b.message || b.error)) || "");
        if (/bucket/i.test(m) && /not.*found/i.test(m)) throw new ApiError("File storage isn't available right now. Please try again later.");
        if (/size|large|payload/i.test(m) || res.status === 413) throw new ApiError("The file is too large. The maximum size is 10 MB.");
        if (/security|policy|unauthor/i.test(m) || res.status === 403 || res.status === 401) throw new ApiError("The upload wasn't allowed. Please sign in again and retry.");
        if (/mime|type/i.test(m)) throw new ApiError("This kind of file isn't accepted here.");
        throw new ApiError("The file couldn't be uploaded. Please check your connection and try again.");
      }
      const url = t.public ? `${BASE}/storage/v1/object/public/${t.bucket}/${objPath}` : null;
      return { path: t.path, url, name: file.name, size: file.size, type: file.type, bucket: t.bucket, public: !!t.public };
    },

    /** Get a link for a stored file: public files directly, private files as a 10-minute signed link. */
    async fileUrl(ref) {
      if (/^https?:\/\//i.test(ref || "")) return ref;
      const t = await this.call("files.url", { path: ref });
      const objPath = t.name.split("/").map(encodeURIComponent).join("/");
      if (t.public) return `${BASE}/storage/v1/object/public/${t.bucket}/${objPath}`;
      const res = await request(`${BASE}/storage/v1/object/sign/${t.bucket}/${objPath}`, {
        method: "POST", headers: this.headers(), body: JSON.stringify({ expiresIn: 600 }),
      }, "download");
      let b = null; try { b = await res.json(); } catch { /* ignore */ }
      const signed = b && (b.signedURL || b.signedUrl);
      if (!res.ok || !signed) throw new ApiError("This file is no longer available.");
      return /^https?:/.test(signed) ? signed : `${BASE}/storage/v1${signed.startsWith("/") ? "" : "/"}${signed}`;
    },
  };

  window.API = API;
})();
