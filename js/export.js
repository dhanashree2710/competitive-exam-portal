/* =====================================================================
   export.js – CSV / Excel (.xlsx) / PDF downloads + PDF scorecards.
   Libraries (SheetJS, jsPDF) load only when first used.
   ===================================================================== */
window.Exporter = (function () {
  const loaded = {};
  const load = (src) => loaded[src] || (loaded[src] = new Promise((res, rej) => {
    const s = document.createElement("script"); s.src = src; s.onload = res;
    s.onerror = () => { delete loaded[src]; rej(new API.ApiError("Couldn't load the export tool. Please check your internet connection and try again.")); };
    document.head.appendChild(s);
  }));
  const XLSX_SRC = "https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js";
  const JSPDF_SRC = "https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js";
  const AUTOTABLE_SRC = "https://cdn.jsdelivr.net/npm/jspdf-autotable@3.8.2/dist/jspdf.plugin.autotable.min.js";
  // small CSV reader (quotes, commas and new lines inside quotes)
  function parseCsv(text) {
    const out = []; let row = [], f = "", q = false;
    text = String(text || "").replace(/^\uFEFF/, "");
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (q) { if (c === '"' && text[i + 1] === '"') { f += '"'; i++; } else if (c === '"') q = false; else f += c; }
      else if (c === '"') q = true; else if (c === ",") { row.push(f); f = ""; }
      else if (c === "\n" || c === "\r") { if (c === "\r" && text[i + 1] === "\n") i++; row.push(f); out.push(row); row = []; f = ""; }
      else f += c;
    }
    if (f || row.length) { row.push(f); out.push(row); }
    const rows = out.filter((r) => r.some((c) => String(c).trim()));
    if (!rows.length) return [];
    const head = rows[0].map((h) => h.trim());
    return rows.slice(1).map((r, i) => ({ _line: i + 2, ...Object.fromEntries(head.map((h, j) => [h, String(r[j] ?? "").trim()])) }));
  }
  const safeName = (t) => String(t || "report").replace(/[^\w\- ]+/g, "").trim().replace(/\s+/g, "_").slice(0, 80) || "report";
  const stamp = () => new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata", day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
  const cell = (v) => (v === null || v === undefined ? "" : typeof v === "object" ? JSON.stringify(v) : v);

  function download(blob, filename) {
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = filename;
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 4000);
  }
  async function jspdf() { await load(JSPDF_SRC); await load(AUTOTABLE_SRC); return window.jspdf.jsPDF; }

  return {
    download,
    csv(title, columns, rows) {
      const esc = (v) => `"${String(cell(v)).replace(/"/g, '""')}"`;
      const text = [columns, ...rows].map((r) => r.map(esc).join(",")).join("\r\n");
      download(new Blob(["﻿" + text], { type: "text/csv;charset=utf-8" }), `${safeName(title)}.csv`);
    },
    async xlsx(title, columns, rows) {
      await load(XLSX_SRC);
      const ws = XLSX.utils.aoa_to_sheet([[title], [`Generated ${stamp()}`], [], columns, ...rows.map((r) => r.map(cell))]);
      ws["!cols"] = columns.map((c, i) => ({ wch: Math.min(50, Math.max(String(c).length, ...rows.slice(0, 200).map((r) => String(cell(r[i])).length)) + 2) }));
      const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, "Report");
      XLSX.writeFile(wb, `${safeName(title)}.xlsx`);
    },
    /** Read an uploaded .csv / .xlsx / .xls file → array of row objects keyed by the header row (first sheet) */
    async readRows(file) {
      const name = (file.name || "").toLowerCase();
      if (name.endsWith(".csv") || name.endsWith(".txt")) return parseCsv(await file.text());
      if (!/\.(xlsx|xls)$/.test(name)) throw new Error("Please choose an Excel (.xlsx) or CSV file.");
      await load(XLSX_SRC);
      const wb = XLSX.read(await file.arrayBuffer(), { type: "array", cellDates: true });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const aoa = XLSX.utils.sheet_to_json(ws, { header: 1, raw: false, dateNF: "yyyy-mm-dd", defval: "" });
      const hi = aoa.findIndex((r) => r.filter((c) => String(c).trim()).length >= 2);   // skip title lines above the header
      if (hi < 0) return [];
      const head = aoa[hi].map((h) => String(h).trim());
      return aoa.slice(hi + 1).filter((r) => r.some((c) => String(c).trim())).map((r, i) => ({ _line: hi + i + 2, ...Object.fromEntries(head.map((h, j) => [h, String(r[j] ?? "").trim()])) }));
    },
    /** One Excel workbook with several sheets: sheets = [{ name, columns, rows }] */
    async workbook(title, sheets) {
      await load(XLSX_SRC);
      const wb = XLSX.utils.book_new(); const used = new Set();
      sheets.forEach((sh) => {
        let nm = String(sh.name || "Sheet").replace(/[\\/?*[\]:]/g, " ").slice(0, 31) || "Sheet"; while (used.has(nm)) nm = nm.slice(0, 28) + "_" + used.size; used.add(nm);
        const ws = XLSX.utils.aoa_to_sheet([[`${title} – ${sh.name}`], [`Generated ${stamp()} · ${sh.rows.length} row(s)`], [], sh.columns, ...sh.rows.map((r) => r.map(cell))]);
        ws["!cols"] = sh.columns.map((c, i) => ({ wch: Math.min(45, Math.max(String(c).length, ...sh.rows.slice(0, 200).map((r) => String(cell(r[i])).length)) + 2) }));
        ws["!autofilter"] = { ref: XLSX.utils.encode_range({ s: { r: 3, c: 0 }, e: { r: 3 + sh.rows.length, c: sh.columns.length - 1 } }) };
        XLSX.utils.book_append_sheet(wb, ws, nm);
      });
      XLSX.writeFile(wb, `${safeName(title)}.xlsx`);
    },
    async pdf(title, columns, rows, { landscape = columns.length > 7, subtitle = "", images = [] } = {}) {
      const JsPDF = await jspdf();
      const doc = new JsPDF({ orientation: landscape ? "landscape" : "portrait", unit: "pt", format: "a4" });
      doc.setFont("times", "bold"); doc.setFontSize(16); doc.text(title, 40, 44);
      doc.setFont("times", "normal"); doc.setFontSize(10); doc.setTextColor(110);
      doc.text(`${subtitle ? subtitle + "  ·  " : ""}Generated ${stamp()}  ·  ${rows.length} row(s)`, 40, 62);
      let y0 = 76;
      if (images.length) {                       // charts above the table, up to three per row
        const W = doc.internal.pageSize.getWidth() - 80, per = Math.min(3, images.length), gap = 12, w = (W - gap * (per - 1)) / per, h = w * 0.62;
        images.forEach((im, i) => {
          const x = 40 + (i % per) * (w + gap), y = y0 + Math.floor(i / per) * (h + 28);
          doc.setFont("times", "bold"); doc.setFontSize(10); doc.setTextColor(30, 27, 75); doc.text(im.title || "", x, y + 10);
          doc.addImage(im.src, "PNG", x, y + 16, w, h);
        });
        y0 += Math.ceil(images.length / per) * (h + 28) + 8;
        if (y0 > doc.internal.pageSize.getHeight() - 120) { doc.addPage(); y0 = 50; }
      }
      doc.autoTable({ head: [columns], body: rows.map((r) => r.map((v) => String(cell(v)))), startY: y0,
        styles: { font: "times", fontSize: 9, cellPadding: 4 }, headStyles: { fillColor: [79, 70, 229], textColor: 255 },
        alternateRowStyles: { fillColor: [245, 246, 255] }, margin: { left: 40, right: 40 },
        didDrawPage: (d) => { doc.setFontSize(8); doc.setTextColor(150); doc.text(`Page ${d.pageNumber}`, doc.internal.pageSize.getWidth() - 70, doc.internal.pageSize.getHeight() - 18); } });
      doc.save(`${safeName(title)}.pdf`);
    },
    /** Build a one-page PDF scorecard. Returns a Blob (also usable for upload). */
    async scorecard(r, review, qrDataUrl) {
      const JsPDF = await jspdf();
      const doc = new JsPDF({ unit: "pt", format: "a4" });
      const W = doc.internal.pageSize.getWidth();
      doc.setFillColor(79, 70, 229); doc.rect(0, 0, W, 96, "F");
      doc.setTextColor(255); doc.setFont("times", "bold"); doc.setFontSize(22); doc.text("SCORECARD", 40, 46);
      doc.setFont("times", "normal"); doc.setFontSize(12); doc.text(`${r.organization?.name || (window.APP_CONFIG || {}).APP_NAME || "VidyaSetu"}`, 40, 70);
      doc.setTextColor(30); doc.setFont("times", "bold"); doc.setFontSize(16); doc.text(r.exam?.title || "Exam", 40, 132);
      doc.setFont("times", "normal"); doc.setFontSize(12);
      const info = [["Student", r.user?.full_name || ""], ["Roll number", r.user?.roll_number || "—"], ["Email", r.user?.email || "—"],
        ["Submitted", UI.fmtDateTime(r.attempt?.submitted_at)], ["Attempt", String(r.attempt?.attempt_number ?? 1)]];
      info.forEach(([k, v], i) => { doc.setTextColor(110); doc.text(k, 40, 158 + i * 18); doc.setTextColor(30); doc.text(String(v), 140, 158 + i * 18); });
      const pass = Number(r.percentage) >= Number(r.exam?.pass_percentage ?? 33);
      const boxes = [["Score", `${UI.num(r.total_score)} / ${UI.num(r.max_score)}`], ["Percentage", `${UI.num(r.percentage, 1)}%`], ["Rank", String(r.rank ?? "—")],
        ["Percentile", r.percentile != null ? UI.num(r.percentile, 1) : "—"], ["Accuracy", `${UI.num(r.accuracy, 1)}%`], ["Result", pass ? "PASS" : "FAIL"]];
      boxes.forEach(([k, v], i) => {
        const x = 40 + (i % 3) * 175, y = 260 + Math.floor(i / 3) * 70;
        doc.setDrawColor(199, 210, 254); doc.setFillColor(245, 246, 255); doc.roundedRect(x, y, 160, 56, 8, 8, "FD");
        doc.setFontSize(10); doc.setTextColor(110); doc.text(k, x + 12, y + 20);
        doc.setFont("times", "bold"); doc.setFontSize(16); doc.setTextColor(k === "Result" ? (pass ? 22 : 220) : 30, k === "Result" ? (pass ? 163 : 38) : 30, k === "Result" ? (pass ? 74 : 38) : 30);
        doc.text(v, x + 12, y + 42); doc.setFont("times", "normal");
      });
      const sw = Object.entries(r.subject_wise || {});
      if (sw.length) {
        doc.autoTable({ startY: 410, head: [["Subject", "Score", "Max", "Correct", "Wrong", "Skipped"]],
          body: sw.map(([k, v]) => [k, UI.num(v.score), UI.num(v.max), v.correct, v.wrong, v.unattempted]),
          styles: { font: "times", fontSize: 10 }, headStyles: { fillColor: [15, 118, 110] }, margin: { left: 40, right: 40 } });
      }
      const counts = review.reduce((a, q) => { a[q.status] = (a[q.status] || 0) + 1; return a; }, {});
      const y = (doc.lastAutoTable?.finalY || 410) + 30;
      doc.setFontSize(11); doc.setTextColor(60);
      doc.text(`Questions: ${review.length}   Correct: ${counts.correct || 0}   Wrong: ${counts.wrong || 0}   Not answered: ${counts.unattempted || 0}`, 40, y);
      doc.text(`Time taken: ${UI.duration(r.time_spent_seconds)}`, 40, y + 18);
      if (qrDataUrl) { try { doc.addImage(qrDataUrl, "PNG", W - 150, 118, 100, 100); } catch { /* ignore */ } }
      doc.setFontSize(10); doc.setTextColor(110);
      doc.text(`Verification code: ${r.verify_code || "—"}`, W - 190, 236);
      doc.text("Verify online by scanning the QR code.", 40, doc.internal.pageSize.getHeight() - 40);
      doc.text(`Generated ${stamp()}`, W - 190, doc.internal.pageSize.getHeight() - 40);
      return doc.output("blob");
    },
  };
})();
