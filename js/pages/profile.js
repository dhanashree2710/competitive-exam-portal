App.init().then((user) => {
  const el = document.getElementById("app");
  const render = (u) => {
    el.innerHTML = `<h1 class="page-title mb-3"><i class="bi bi-person-circle me-2 text-primary"></i>My profile</h1>
    <div class="row g-3"><div class="col-lg-6"><div class="card"><div class="card-header">Personal details</div><div class="card-body">
      <div class="d-flex align-items-center gap-3 mb-3"><span class="avatar" style="width:64px;height:64px;font-size:1.4rem">${u.avatar_url ? `<img src="${UI.esc(u.avatar_url)}" alt="">` : UI.esc(UI.initials(u.full_name))}</span>
        <div><div class="fw-semibold">${UI.esc(u.email)}</div><div class="small text-secondary">${UI.roleLabel(u.role)}${u.organization ? " · " + UI.esc(u.organization.name) : ""}${u.roll_number ? " · Roll " + UI.esc(u.roll_number) : ""}</div>
        <label class="btn btn-sm btn-light mt-2 mb-0"><i class="bi bi-camera me-1"></i>Change photo<input type="file" accept=".jpg,.jpeg,.png,.webp" hidden id="avatarFile"></label></div></div>
      <form id="pf" novalidate><div class="mb-3"><label class="form-label required">Full name</label><input class="form-control" name="full_name" value="${UI.esc(u.full_name)}" required></div>
      <div class="mb-3"><label class="form-label">Phone</label><input class="form-control" name="phone" value="${UI.esc(u.phone || "")}"></div>
      <button class="btn btn-primary">Save details</button></form></div></div></div>
    <div class="col-lg-6"><div class="card"><div class="card-header">Change password</div><div class="card-body">
      <form id="pw" novalidate><div class="mb-3"><label class="form-label required">Current password</label><input type="password" class="form-control" name="current_password" autocomplete="current-password"></div>
      <div class="mb-3"><label class="form-label required">New password</label><input type="password" class="form-control" name="new_password" autocomplete="new-password"><div class="form-text">At least 8 characters, with letters and numbers.</div></div>
      <div class="mb-3"><label class="form-label required">Confirm new password</label><input type="password" class="form-control" name="confirm" autocomplete="new-password"></div>
      <button class="btn btn-primary">Change password</button></form></div></div></div></div>`;
    el.querySelector("#pf").onsubmit = async (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      if (!String(f.get("full_name")).trim()) return UI.warn("Please enter your name.");
      const r = await UI.run(() => API.call("profile.update", { full_name: f.get("full_name"), phone: f.get("phone") }));
      if (r?.user) { API.setUser(r.user); App.render(r.user, 0); }
    };
    el.querySelector("#avatarFile").onchange = async (e) => {
      const file = e.target.files[0]; if (!file) return;
      if (!/^image\//.test(file.type)) return UI.warn("Please choose an image (JPG, PNG or WebP).");
      let blob;
      try {   // resize to a 320px square so the photo loads fast everywhere
        const img = await createImageBitmap(file);
        const c = document.createElement("canvas"); const size = 320; c.width = c.height = size;
        const k = Math.max(size / img.width, size / img.height); const w = img.width * k, h = img.height * k;
        c.getContext("2d").drawImage(img, (size - w) / 2, (size - h) / 2, w, h);
        blob = await new Promise((res) => c.toBlob(res, "image/jpeg", 0.88));
      } catch { return UI.warn("This image couldn't be read. Please try another photo."); }
      const up = await UI.run(() => API.upload(new File([blob], "avatar.jpg", { type: "image/jpeg" }), "avatar"), { loading: "Uploading photo…", success: false });
      if (!up) return;
      const r = await UI.run(() => API.call("profile.update", { avatar_url: up.url }), { success: "Photo updated." });
      if (r?.user) { API.setUser(r.user); App.render(r.user, 0); render(r.user); }
    };
    el.querySelector("#pw").onsubmit = async (e) => {
      e.preventDefault();
      const f = Object.fromEntries(new FormData(e.target));
      if (!f.current_password || !f.new_password) return UI.warn("Please fill in all password fields.");
      if (f.new_password.length < 8 || !/[A-Za-z]/.test(f.new_password) || !/[0-9]/.test(f.new_password)) return UI.warn("The new password must be at least 8 characters and include letters and numbers.");
      if (f.new_password !== f.confirm) return UI.warn("The new passwords don't match.");
      const r = await UI.run(() => API.call("auth.changePassword", { current_password: f.current_password, new_password: f.new_password }), { quiet: true });
      if (r) { UI.success(r.message); e.target.reset(); }
    };
  };
  render(user);
  const admins = App.me?.org_admins || [];
  if (user.role !== "super_admin") el.insertAdjacentHTML("beforeend", `<div class="card mt-3"><div class="card-header"><i class="bi bi-person-badge me-1 text-primary"></i>Your organization admin</div><div class="card-body">
    ${admins.length ? admins.map((a) => `<div class="mb-1"><b>${UI.esc(a.full_name)}</b> · <a href="mailto:${UI.esc(a.email)}">${UI.esc(a.email)}</a>${a.phone ? " · " + UI.esc(a.phone) : ""}</div>`).join("") : '<span class="text-secondary">No admin set yet.</span>'}</div></div>`);

  // students: the full student record (read-only school details + editable contact details)
  if (user.role === "student") (async () => {
    let d; try { d = await API.call("student.get", {}); } catch { return; }
    const s = d.student, esc = UI.esc, v = (x) => (x === null || x === undefined || x === "" ? "—" : esc(x));
    const cell = (k, x) => `<div class="col-sm-6 col-lg-4"><div class="info-cell"><span>${k}</span><b>${x}</b></div></div>`;
    el.insertAdjacentHTML("beforeend", `<div class="card mt-3"><div class="card-header d-flex align-items-center"><i class="bi bi-mortarboard me-2 text-primary"></i>My student record
      <span class="ms-auto small text-secondary">Kept by your institute – ask the office to correct school details</span></div><div class="card-body"><div class="row g-2">
      ${cell("Roll number", v(s.roll_number))}${cell("Admission number", v(s.admission_no))}${cell("Batch", v(s.batch?.name))}
      ${cell("Date of birth", s.date_of_birth ? UI.fmtDate(s.date_of_birth) : "—")}${cell("Gender", v({ male: "Male", female: "Female", other: "Other" }[s.gender]))}${cell("Blood group", v(s.blood_group))}
      ${cell("Father", v(s.father_name))}${cell("Mother", v(s.mother_name))}${cell("School", v(s.school_name))}
      ${cell("Board", v(s.board))}${cell("Class 10 %", s.class_10_percent ? s.class_10_percent + "%" : "—")}${cell("Fee status", v({ paid: "Paid", partial: "Partly paid", pending: "Pending" }[s.fee_status]))}
      </div><hr><h6 class="mb-3">Contact details you can update</h6>
      <form id="sf" class="row g-3" novalidate>
        <div class="col-12"><label class="form-label">Address</label><input class="form-control" name="address_line" value="${esc(s.address_line || "")}"></div>
        <div class="col-md-4"><label class="form-label">City</label><input class="form-control" name="city" value="${esc(s.city || "")}"></div>
        <div class="col-md-4"><label class="form-label">State</label><input class="form-control" name="state" value="${esc(s.state || "")}"></div>
        <div class="col-md-4"><label class="form-label">PIN code</label><input class="form-control" name="pincode" value="${esc(s.pincode || "")}"></div>
        <div class="col-md-4"><label class="form-label">Alternate phone</label><input class="form-control" name="alt_phone" value="${esc(s.alt_phone || "")}"></div>
        <div class="col-md-4"><label class="form-label">Father's phone</label><input class="form-control" name="father_phone" value="${esc(s.father_phone || "")}"></div>
        <div class="col-md-4"><label class="form-label">Mother's phone</label><input class="form-control" name="mother_phone" value="${esc(s.mother_phone || "")}"></div>
        <div class="col-12"><button class="btn btn-primary">Save contact details</button></div></form></div></div>`);
    el.querySelector("#sf").onsubmit = async (e) => {
      e.preventDefault();
      const f = Object.fromEntries(new FormData(e.target));
      if (f.pincode && !/^[1-9]\d{5}$/.test(f.pincode)) return UI.warn("Please enter a valid 6-digit PIN code.");
      await UI.run(() => API.call("student.updatemine", f));
    };
  })();
});
