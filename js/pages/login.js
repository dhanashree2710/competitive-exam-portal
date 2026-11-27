(function () {
  const C = window.APP_CONFIG || {};
  if (!window.APP_CONFIG || /YOUR-/.test((window.APP_CONFIG.SUPABASE_URL || "") + (window.APP_CONFIG.SUPABASE_ANON_KEY || "")))
    UI.error("This website isn't linked to the exam server yet. Administrator: please upload the file js/config.js (with your Supabase address and public key) to the server.", "Setup needed");
  if (C.APP_NAME && C.APP_NAME !== "VidyaSetu") document.querySelectorAll(".app-name").forEach((e) => (e.textContent = C.APP_NAME));
  document.title = `Sign in · ${C.APP_NAME || "VidyaSetu"}`;
  const qs = new URLSearchParams(location.search);
  if (qs.get("expired")) UI.info("Your session has expired. Please sign in again.", "Signed out");
  if (qs.get("logout")) UI.toast("You have been signed out.");
  if (API.token && !qs.get("expired")) API.call("auth.me", {}, { noRedirect: true }).then(() => location.replace("pages/dashboard.html")).catch(() => API.clear());

  const email = document.getElementById("email"), pw = document.getElementById("password");
  const btn = document.getElementById("loginBtn"), errBox = document.getElementById("loginError");
  try { localStorage.removeItem("ep_last_email"); } catch { /* ignore */ }   // emails are no longer remembered
  email.value = ""; email.focus();

  document.getElementById("togglePw").addEventListener("click", (e) => {
    const show = pw.type === "password"; pw.type = show ? "text" : "password";
    e.currentTarget.innerHTML = `<i class="bi bi-eye${show ? "-slash" : ""}"></i>`;
  });
  document.getElementById("forgot").addEventListener("click", (e) => { e.preventDefault(); UI.info("Please ask your institute administrator to reset your password. They can do it from the Users page.", "Forgot password"); });

  document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    errBox.classList.add("d-none"); [email, pw].forEach((i) => i.classList.remove("is-invalid"));
    if (!/^\S+@\S+\.\S+$/.test(email.value.trim())) { email.classList.add("is-invalid"); return showErr("Please enter a valid email address."); }
    if (!pw.value) { pw.classList.add("is-invalid"); return showErr("Please enter your password."); }
    btn.disabled = true; btn.innerHTML = `<span class="spinner-border spinner-border-sm me-2"></span>Signing in…`;
    try {
      const r = await API.call("auth.login", { email: email.value.trim(), password: pw.value }, { noRedirect: true });
      API.setSession(r.token, r.user);
      try {   // Remember me = stay signed in on this device; otherwise sign out when the browser closes
        if (document.getElementById("remember").checked) localStorage.removeItem("ep_session_only");
        else { localStorage.setItem("ep_session_only", "1"); sessionStorage.setItem("ep_alive", "1"); }
      } catch { /* ignore */ }
      btn.innerHTML = `<i class="bi bi-check2-circle me-1"></i>Welcome, ${UI.esc(r.user.full_name.split(" ")[0])}!`;
      document.querySelector(".auth-card").style.cssText = "transition:.4s;opacity:0;transform:translateY(-10px)";
      setTimeout(() => location.replace("pages/dashboard.html"), 380);
    } catch (err) {
      showErr(err.name === "ApiError" ? err.message : "Something went wrong. Please try again.");
      document.querySelector(".auth-card").animate([{ transform: "translateX(0)" }, { transform: "translateX(-8px)" }, { transform: "translateX(8px)" }, { transform: "translateX(0)" }], { duration: 300 });
      btn.disabled = false; btn.innerHTML = 'Sign in <i class="bi bi-arrow-right ms-1"></i>';
      pw.select();
    }
  });
  function showErr(m) { errBox.textContent = m; errBox.classList.remove("d-none"); }
})();
