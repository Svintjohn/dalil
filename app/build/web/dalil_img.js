/* Shrinks a photo with the browser's own image code, which is far faster than doing it in Dart.
   Resolves to the new JPEG bytes, or null when the browser cannot do it (the app then uses its Dart fallback). */
(function () {
  'use strict';
  window.dalilImg = {
    shrink: async function (bytes, side, quality) {
      try {
        var bmp = await createImageBitmap(new Blob([bytes]), { imageOrientation: 'from-image' });
        var w = bmp.width, h = bmp.height, big = Math.max(w, h);
        if (!w || !h) return null;
        if (big > side) { var k = side / big; w = Math.max(1, Math.round(w * k)); h = Math.max(1, Math.round(h * k)); }
        var c = document.createElement('canvas');
        c.width = w; c.height = h;
        var ctx = c.getContext('2d');
        if (!ctx) return null;
        ctx.fillStyle = '#ffffff';           // a transparent PNG would turn black as a JPEG
        ctx.fillRect(0, 0, w, h);
        ctx.drawImage(bmp, 0, 0, w, h);
        if (bmp.close) bmp.close();
        var blob = await new Promise(function (resolve) { c.toBlob(resolve, 'image/jpeg', quality); });
        if (!blob) return null;
        return new Uint8Array(await blob.arrayBuffer());
      } catch (e) {
        return null;
      }
    },
  };
})();
