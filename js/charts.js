/* Charts – a small built-in SVG chart library (no internet needed): bar, horizontal bar, line, doughnut, radar.
   Charts.draw(target, { type, labels, series:[{label, data, color, colors}], percent, horizontal, rainbow, keepLabels, empty })
   Charts.toPng(host) → data URL (used to put charts into PDFs) */
(function () {
  const PALETTE = ["#2563EB", "#0EA5E9", "#F97316", "#F59E0B", "#10B981", "#F43F5E", "#0EA5E9", "#EC4899", "#84CC16", "#64748B"];
  const FONT = "'Times New Roman', Times, serif";
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const short = (t, n) => { t = String(t ?? ""); return t.length > n ? t.slice(0, n - 1) + "…" : t; };
  const fmt = (v, pct) => (v === null || v === undefined || isNaN(v) ? "—" : (Math.round(Number(v) * 10) / 10).toLocaleString("en-IN") + (pct ? "%" : ""));
  const niceMax = (m, pct) => { if (pct) return 100; if (m <= 0) return 1; const p = Math.pow(10, Math.floor(Math.log10(m))); const n = m / p; return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * p; };
  /** axis top and 4 equal steps; whole-number steps when every value is a whole number (counts) */
  const axis = (vals, pct) => {
    const m = Math.max(0, ...vals.filter((v) => !isNaN(v)));
    if (pct) return { max: 100, step: 25 };
    if (vals.every((v) => Number.isInteger(v))) { const step = Math.max(1, Math.ceil(m / 4)); return { max: step * 4, step }; }
    const max = niceMax(m, false); return { max, step: max / 4 };
  };
  let uid = 0;
  const state = new WeakMap();

  function svgOpen(w, h) { return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" font-family="${FONT}" class="ep-chart" role="img">`; }

  function bars(o, W, H) {
    const s = o.series, labels = o.labels, multi = s.length > 1, pct = o.percent;
    const ax = axis(s.flatMap((x) => x.data.map(Number)), pct), max = ax.max;
    if (o.horizontal) {
      const L = Math.min(150, Math.max(70, W * 0.32)), T = 6, R = 44, rowH = Math.max(18, Math.min(30, (H - T - 6) / Math.max(1, labels.length)));
      const h = T + rowH * labels.length + 6, cw = W - L - R;
      let g = svgOpen(W, h);
      labels.forEach((lb, i) => {
        const y = T + i * rowH, v = Number(s[0].data[i]) || 0, bw = Math.max(2, (cw * v) / max), c = s[0].colors?.[i] || (o.rainbow ? PALETTE[i % PALETTE.length] : s[0].color || PALETTE[0]);
        g += `<text x="${L - 8}" y="${y + rowH / 2 + 4}" text-anchor="end" font-size="12" fill="#334155">${esc(short(lb, Math.floor(L / 6.5)))}</text>`;
        g += `<rect x="${L}" y="${y + rowH * 0.18}" width="${cw}" height="${rowH * 0.64}" rx="${rowH * 0.32}" fill="#EEF0F8"/>`;
        g += `<rect class="grow-x" style="animation-delay:${i * 40}ms" x="${L}" y="${y + rowH * 0.18}" width="${bw}" height="${rowH * 0.64}" rx="${rowH * 0.32}" fill="${c}"><title>${esc(lb)}: ${fmt(v, pct)}</title></rect>`;
        g += `<text x="${L + bw + 6}" y="${y + rowH / 2 + 4}" font-size="12" font-weight="700" fill="#0F1E3D">${fmt(v, pct)}</text>`;
      });
      return g + "</svg>";
    }
    const L = 34, B = 34, T = 14, R = 8, ch = H - T - B, cw = W - L - R, n = labels.length, slot = cw / Math.max(1, n);
    const bw = Math.min(46, (slot * 0.62) / s.length);
    let g = svgOpen(W, H);
    for (let k = 0; k <= 4; k++) {
      const y = T + ch - (ch * k) / 4;
      g += `<line x1="${L}" x2="${W - R}" y1="${y}" y2="${y}" stroke="#E7E9F3" ${k ? 'stroke-dasharray="3 4"' : ""}/>`;
      g += `<text x="${L - 6}" y="${y + 4}" text-anchor="end" font-size="11" fill="#7A8299">${fmt(ax.step * k, pct)}</text>`;
    }
    const every = Math.ceil(n / Math.max(1, Math.floor(cw / 46)));
    labels.forEach((lb, i) => {
      s.forEach((se, j) => {
        const v = Number(se.data[i]) || 0, bh = (ch * v) / max, x = L + i * slot + (slot - bw * s.length) / 2 + j * bw, y = T + ch - bh;
        const c = se.colors?.[i] || (o.rainbow && !multi ? PALETTE[i % PALETTE.length] : se.color || PALETTE[j % PALETTE.length]);
        g += `<rect class="grow-y" style="animation-delay:${i * 50}ms" x="${x + 2}" y="${y}" width="${Math.max(2, bw - 4)}" height="${Math.max(0, bh)}" rx="7" fill="${c}"><title>${esc(lb)}${multi ? " – " + esc(se.label) : ""}: ${fmt(v, pct)}</title></rect>`;
        if (!multi && bh > 0) g += `<text x="${x + bw / 2}" y="${y - 5}" text-anchor="middle" font-size="11" font-weight="700" fill="#0F1E3D">${fmt(v, pct)}</text>`;
      });
      if (i % every === 0) g += `<text x="${L + i * slot + slot / 2}" y="${H - B + 18}" text-anchor="middle" font-size="${slot < 60 ? 10.5 : 11.5}" fill="#475069">${esc(short(lb, Math.max(6, Math.floor((slot * every) / 5.6))))}</text>`;
    });
    return g + "</svg>";
  }

  function line(o, W, H) {
    const s = o.series, labels = o.labels, pct = o.percent, L = 40, B = 34, T = 22, R = 18, ch = H - T - B, cw = W - L - R, n = labels.length;
    const ax = axis(s.flatMap((x) => x.data.map(Number)), pct), max = ax.max;
    const X = (i) => L + (n === 1 ? cw / 2 : (cw * i) / (n - 1)), Y = (v) => T + ch - (ch * (Number(v) || 0)) / max;
    let g = svgOpen(W, H), id = "lg" + ++uid;
    for (let k = 0; k <= 4; k++) { const y = T + ch - (ch * k) / 4; g += `<line x1="${L}" x2="${W - R}" y1="${y}" y2="${y}" stroke="#E7E9F3" ${k ? 'stroke-dasharray="3 4"' : ""}/><text x="${L - 6}" y="${y + 4}" text-anchor="end" font-size="11" fill="#7A8299">${fmt(ax.step * k, pct)}</text>`; }
    s.forEach((se, j) => {
      const c = se.color || PALETTE[j % PALETTE.length], pts = se.data.map((v, i) => [X(i), Y(v)]);
      const d = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
      g += `<defs><linearGradient id="${id}${j}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c}" stop-opacity=".32"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></linearGradient></defs>`;
      if (pts.length > 1) g += `<path d="${d} L${pts[pts.length - 1][0]} ${T + ch} L${pts[0][0]} ${T + ch} Z" fill="url(#${id}${j})"/>`;
      g += `<path class="draw" d="${d}" fill="none" stroke="${c}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
      pts.forEach((p, i) => { g += `<circle class="pop" style="animation-delay:${i * 60}ms" cx="${p[0]}" cy="${p[1]}" r="5" fill="#fff" stroke="${c}" stroke-width="2.5"><title>${esc(labels[i])}: ${fmt(se.data[i], pct)}</title></circle>`;
        if (s.length === 1) g += `<text x="${p[0]}" y="${p[1] - 10}" text-anchor="middle" font-size="11" font-weight="700" fill="#0F1E3D">${fmt(se.data[i], pct)}</text>`; });
    });
    const every = Math.ceil(n / Math.max(1, Math.floor(cw / 80)));
    labels.forEach((lb, i) => { if (i % every === 0) g += `<text x="${X(i)}" y="${H - B + 18}" text-anchor="${n > 1 && i === 0 ? "start" : n > 1 && i === n - 1 ? "end" : "middle"}" font-size="11.5" fill="#475069">${esc(short(lb, n <= 2 ? 22 : 14))}</text>`; });
    return g + "</svg>";
  }

  function doughnut(o, W, H) {
    const vals = o.series[0].data.map((v) => Number(v) || 0), total = vals.reduce((a, b) => a + b, 0), colors = o.series[0].colors || PALETTE;
    const legendW = W > 380 ? Math.min(170, W * 0.42) : 0; if (!legendW) H = H - 22 * Math.ceil(o.labels.length / 2) - 6;
    const size = Math.min(H - 10, W - legendW - 10), r = size / 2 - 4, cx = (W - legendW) / 2, cy = H / 2, ir = r * 0.62;
    let g = svgOpen(W, H), a0 = -Math.PI / 2;
    const arc = (a1, a2) => { const lg = a2 - a1 > Math.PI ? 1 : 0, p = (a, rr) => [cx + rr * Math.cos(a), cy + rr * Math.sin(a)];
      const [x1, y1] = p(a1, r), [x2, y2] = p(a2, r), [x3, y3] = p(a2, ir), [x4, y4] = p(a1, ir);
      return `M${x1} ${y1} A${r} ${r} 0 ${lg} 1 ${x2} ${y2} L${x3} ${y3} A${ir} ${ir} 0 ${lg} 0 ${x4} ${y4} Z`; };
    vals.forEach((v, i) => {
      if (!v) return; const a = (v / total) * Math.PI * 2, gap = vals.filter(Boolean).length > 1 ? 0.025 : 0;
      g += `<path class="pop" style="animation-delay:${i * 70}ms" d="${arc(a0 + gap, a0 + a - gap)}" fill="${colors[i % colors.length]}"><title>${esc(o.labels[i])}: ${fmt(v)} (${Math.round((100 * v) / total)}%)</title></path>`;
      a0 += a;
    });
    g += `<text x="${cx}" y="${cy + 2}" text-anchor="middle" font-size="${Math.max(16, r * 0.38)}" font-weight="700" fill="#0F1E3D">${fmt(total)}</text>`;
    g += `<text x="${cx}" y="${cy + 18}" text-anchor="middle" font-size="11" fill="#7A8299">total</text>`;
    const items = o.labels.map((l, i) => [l, vals[i], colors[i % colors.length]]);
    if (legendW) items.forEach(([l, v, c], i) => { const y = cy - (items.length * 22) / 2 + i * 22 + 12, x = W - legendW + 6;
      g += `<rect x="${x}" y="${y - 9}" width="11" height="11" rx="3" fill="${c}"/><text x="${x + 18}" y="${y}" font-size="12" fill="#334155">${esc(short(l, 16))}</text><text x="${W - 4}" y="${y}" text-anchor="end" font-size="12" font-weight="700" fill="#0F1E3D">${fmt(v)}</text>`; });
    g += "</svg>";
    if (!legendW) g += `<div class="chart-legend">${items.map(([l, v, c]) => `<span><i style="background:${c}"></i>${esc(l)} <b>${fmt(v)}</b></span>`).join("")}</div>`;
    return g;
  }

  function radar(o, W, H) {
    const vals = o.series[0].data.map((v) => Number(v) || 0), n = o.labels.length, c = o.series[0].color || PALETTE[2], cx = W / 2, cy = H / 2 + 4, r = Math.min(W * 0.34, H / 2 - 22);
    const P = (i, f) => [cx + r * f * Math.sin((2 * Math.PI * i) / n), cy - r * f * Math.cos((2 * Math.PI * i) / n)];
    let g = svgOpen(W, H);
    [0.25, 0.5, 0.75, 1].forEach((f) => { g += `<polygon points="${o.labels.map((_, i) => P(i, f).join(",")).join(" ")}" fill="${f === 1 ? "#F5F8FC" : "none"}" stroke="#E2E5F0"/>`; });
    o.labels.forEach((l, i) => { const [x, y] = P(i, 1), [tx, ty] = P(i, 1.16); g += `<line x1="${cx}" y1="${cy}" x2="${x}" y2="${y}" stroke="#E2E5F0"/>`;
      g += `<text x="${tx}" y="${ty + 4}" text-anchor="${Math.abs(tx - cx) < 4 ? "middle" : tx > cx ? "start" : "end"}" font-size="12" fill="#334155">${esc(short(l, 14))}</text>`; });
    g += `<polygon class="pop" points="${vals.map((v, i) => P(i, Math.min(1, v / 100)).join(",")).join(" ")}" fill="${c}33" stroke="${c}" stroke-width="2.5"/>`;
    vals.forEach((v, i) => { const [x, y] = P(i, Math.min(1, v / 100)); g += `<circle cx="${x}" cy="${y}" r="4.5" fill="#fff" stroke="${c}" stroke-width="2.5"><title>${esc(o.labels[i])}: ${fmt(v, true)}</title></circle>`; });
    return g + "</svg>";
  }

  function render(host) {
    const st = state.get(host); if (!st) return;
    const o = st.opts, W = Math.max(220, Math.floor(host.clientWidth || 320)), H = Math.max(180, Math.floor(host.clientHeight || 240));
    const t = o.type === "bar" ? bars : o.type === "line" ? line : o.type === "radar" ? radar : doughnut;
    host.innerHTML = t(o, W, H);
    st.w = W;
  }

  window.Charts = {
    PALETTE,
    async draw(target, opts) {
      const host = typeof target === "string" ? document.querySelector(target) : target;
      if (!host) return null;
      const o = { type: "bar", ...opts, labels: opts.labels || [], series: (opts.series || []).map((x) => ({ ...x, data: (x.data || []).map((v) => (v === null || v === undefined ? 0 : Number(v))) })) };
      const has = o.labels.length && o.series.some((x) => x.data.some((v) => v > 0));
      if (!has) { state.delete(host); host.innerHTML = `<div class="chart-empty"><i class="bi bi-bar-chart"></i>${esc(o.empty || "No data yet")}</div>`; return null; }
      if (o.type === "doughnut" || o.type === "pie") o.type = "doughnut";
      state.set(host, { opts: o });
      render(host);
      if (!host._ro && window.ResizeObserver) {
        let t; host._ro = new ResizeObserver(() => { clearTimeout(t); t = setTimeout(() => { const s = state.get(host); if (s && Math.abs((host.clientWidth || 0) - s.w) > 8) render(host); }, 120); });
        host._ro.observe(host);
      }
      return host;
    },
    /** PNG data URL of the chart inside host (for PDFs) */
    toPng(host, scale = 2) {
      return new Promise((ok) => {
        const svg = host && host.querySelector("svg"); if (!svg) return ok(null);
        const w = Number(svg.getAttribute("width")), h = Number(svg.getAttribute("height"));
        const xml = new XMLSerializer().serializeToString(svg).replace(/class="(grow-x|grow-y|draw|pop)"/g, "");
        const img = new Image();
        img.onload = () => { const c = document.createElement("canvas"); c.width = w * scale; c.height = h * scale; const x = c.getContext("2d"); x.fillStyle = "#fff"; x.fillRect(0, 0, c.width, c.height); x.scale(scale, scale); x.drawImage(img, 0, 0); ok(c.toDataURL("image/png")); };
        img.onerror = () => ok(null);
        img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(xml);
      });
    },
  };
})();
