/* Reads uploaded documents in the browser (nothing is sent anywhere until you confirm):
   PDF (pdf.js), Word .docx (mammoth), Excel/CSV (SheetJS), plain text. Libraries load only when needed. */
window.Docs = (function () {
  const loaded = {};
  const load = (src) => loaded[src] || (loaded[src] = new Promise((res, rej) => {
    const s = document.createElement("script"); s.src = src; s.onload = res;
    s.onerror = () => { delete loaded[src]; rej(new API.ApiError("Couldn't load the document reader. Please check your internet connection.")); };
    document.head.appendChild(s);
  }));
  const ext = (f) => (f.name.split(".").pop() || "").toLowerCase();
  async function pdfText(file) {
    await load("https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.min.js");
    pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.worker.min.js";
    const pdf = await pdfjsLib.getDocument({ data: await file.arrayBuffer() }).promise;
    let out = "";
    for (let i = 1; i <= Math.min(pdf.numPages, 40); i++) {
      const c = await (await pdf.getPage(i)).getTextContent();
      out += c.items.map((x) => x.str + (x.hasEOL ? "\n" : " ")).join("") + "\n";
    }
    return out;
  }
  async function docxText(file) {
    await load("https://cdn.jsdelivr.net/npm/mammoth@1.8.0/mammoth.browser.min.js");
    return (await mammoth.extractRawText({ arrayBuffer: await file.arrayBuffer() })).value;
  }
  return {
    /** text from pdf / docx / txt / csv */
    async text(file) {
      if (!file) throw new API.ApiError("Please choose a file.");
      if (file.size > 15 * 1024 * 1024) throw new API.ApiError("The file is too large (max 15 MB).");
      const e = ext(file);
      let t;
      try {
        if (e === "pdf") t = await pdfText(file);
        else if (e === "docx") t = await docxText(file);
        else if (["txt", "csv", "md"].includes(e)) t = await file.text();
        else throw new API.ApiError("Please upload a PDF, Word (.docx) or text file. Older .doc files: save them as .docx first.");
      } catch (err) { if (err.name === "ApiError") throw err; console.error(err); throw new API.ApiError("This file couldn't be read. It may be scanned (image only) or protected. Try copying the text instead."); }
      t = t.replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim();
      if (t.length < 20) throw new API.ApiError("No readable text was found in this file. Scanned PDFs/images can't be read – please paste the text instead.");
      return t;
    },
    /** rows (array of objects with lower-case keys) from xlsx / xls / csv */
    async rows(file) {
      if (!file) throw new API.ApiError("Please choose a file.");
      const e = ext(file);
      if (!["xlsx", "xls", "csv"].includes(e)) throw new API.ApiError("Please upload an Excel (.xlsx) or CSV file.");
      await load("https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js");
      try {
        const wb = XLSX.read(await file.arrayBuffer(), { type: "array" });
        const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: "" });
        return rows.map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [String(k).trim().toLowerCase().replace(/\s+/g, "_"), String(v).trim()])));
      } catch (err) { console.error(err); throw new API.ApiError("This spreadsheet couldn't be read. Please check the file and try again."); }
    },
    async qr(el, text, size = 110) {
      await load("https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js");
      el.innerHTML = ""; new QRCode(el, { text, width: size, height: size, correctLevel: QRCode.CorrectLevel.M });
    },
  };
})();
