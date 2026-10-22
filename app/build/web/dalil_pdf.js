/* Reads a PDF in the browser. Nothing is uploaded: the file never leaves this device until the app sends the text or
   the page pictures for explaining, exactly like a photo.

   pick(opts): opens the file chooser, then resolves to one of
     null                                  the person closed the chooser
     { ok:false, error:'bad'|'locked'|'empty'|'unsupported', name }
     { ok:true, name, total, kind:'text', text, truncated }        a PDF with real text (not Arabic script)
     { ok:true, name, total, kind:'pages', pages:[Uint8Array...] } a scan, or a PDF in Arabic script: JPEG pictures
   Arabic-script text is read from pictures because text pulled out of a PDF can come out in the wrong order.
   The PDF reader code (web/pdfjs) is loaded only when a PDF is chosen. */
(function () {
  'use strict';
  var lib = null;
  var ARABIC = new RegExp('[' + ['0600-06FF','0750-077F','08A0-08FF','FB50-FDFF','FE70-FEFF'].map(function (r) { return r.split('-').map(function (h) { return String.fromCharCode(parseInt(h, 16)); }).join('-'); }).join('') + ']');

  function load() {
    if (lib) return lib;
    lib = import(new URL('pdfjs/pdf.min.mjs', document.baseURI).href).then(function (m) {
      m.GlobalWorkerOptions.workerSrc = new URL('pdfjs/pdf.worker.min.mjs', document.baseURI).href;
      return m;
    });
    lib.catch(function () { lib = null; });
    return lib;
  }

  function chooser() {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'application/pdf,.pdf';
      input.style.display = 'none';
      var done = false;
      function finish(f) { if (!done) { done = true; input.remove(); resolve(f); } }
      input.addEventListener('change', function () { finish(input.files && input.files[0] ? input.files[0] : null); });
      input.addEventListener('cancel', function () { finish(null); });
      document.body.appendChild(input);
      input.click();
    });
  }

  async function pageText(page) {
    var c = await page.getTextContent();
    var out = '';
    for (var i = 0; i < c.items.length; i++) {
      var it = c.items[i];
      out += it.str;
      out += it.hasEOL ? '\n' : (it.str && !/\s$/.test(it.str) ? ' ' : '');
    }
    return out.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  async function render(page, side, quality) {
    var v1 = page.getViewport({ scale: 1 });
    var k = side / Math.max(v1.width, v1.height);
    var vp = page.getViewport({ scale: k });
    var c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(vp.width));
    c.height = Math.max(1, Math.round(vp.height));
    var ctx = c.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, c.width, c.height);
    await page.render({ canvasContext: ctx, viewport: vp }).promise;
    var blob = await new Promise(function (r) { c.toBlob(r, 'image/jpeg', quality); });
    c.width = c.height = 0;
    if (!blob) return null;
    return new Uint8Array(await blob.arrayBuffer());
  }

  /* opts: maxPages (pictures), maxChars (text), side (longest edge in px), quality (0 to 1), minTextPerPage */
  async function read(file, opts) {
    opts = opts || {};
    var maxPages = opts.maxPages || 6, maxChars = opts.maxChars || 30000, side = opts.side || 1400;
    var quality = opts.quality || 0.82, minPer = opts.minTextPerPage || 120;
    var name = file.name || 'document.pdf';
    var pdfjs;
    try { pdfjs = await load(); } catch (e) { return { ok: false, error: 'unsupported', name: name }; }
    var doc = null;
    try {
      var bytes = new Uint8Array(await file.arrayBuffer());
      doc = await pdfjs.getDocument({ data: bytes, isEvalSupported: false }).promise;
    } catch (e) {
      return { ok: false, error: e && e.name === 'PasswordException' ? 'locked' : 'bad', name: name };
    }
    try {
      var total = doc.numPages;
      if (!total) return { ok: false, error: 'empty', name: name };
      var look = Math.min(total, maxPages), text = '', arabic = false, chars = 0;
      for (var i = 1; i <= look; i++) {
        var t = await pageText(await doc.getPage(i));
        if (ARABIC.test(t)) arabic = true;
        chars += t.replace(/\s/g, '').length;
        text += (text ? '\n\n' : '') + t;
      }
      if (!arabic && chars >= minPer * Math.min(look, 2)) {
        // a PDF with real text: read the rest of it too, up to the limit
        for (var j = look + 1; j <= total && text.length < maxChars; j++) {
          var tj = await pageText(await doc.getPage(j));
          if (ARABIC.test(tj)) { arabic = true; break; }
          text += '\n\n' + tj;
        }
        if (!arabic) {
          var truncated = text.length > maxChars;
          return { ok: true, name: name, total: total, kind: 'text', text: truncated ? text.slice(0, maxChars) : text, truncated: truncated };
        }
      }
      var pages = [];
      for (var p = 1; p <= Math.min(total, maxPages); p++) {
        var jpg = await render(await doc.getPage(p), side, quality);
        if (jpg) pages.push(jpg);
      }
      if (!pages.length) return { ok: false, error: 'empty', name: name };
      return { ok: true, name: name, total: total, kind: 'pages', pages: pages };
    } catch (e) {
      return { ok: false, error: 'bad', name: name };
    } finally {
      try { doc.destroy(); } catch (e) {}
    }
  }

  window.dalilPdf = {
    read: read,
    pick: async function (opts) {
      var f = await chooser();
      return f ? read(f, opts) : null;
    },
  };
})();
