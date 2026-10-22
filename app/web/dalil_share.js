/* Saves or shares a picture the app drew. Everything happens in the browser; nothing is uploaded.
   share(): opens the phone's share sheet with the picture when the browser can. It resolves to 'shared',
   'cancelled' (the person closed the sheet) or 'unsupported' (the app then offers a download instead).
   save(): downloads the picture and returns true or false. Neither throws, so the app can show a calm message. */
(function () {
  'use strict';
  function fileOf(bytes, name, mime) {
    return new File([bytes], name, { type: mime });
  }
  window.dalilShare = {
    share: async function (bytes, name, mime, text) {
      try {
        var f = fileOf(bytes, name, mime);
        if (!navigator.canShare || !navigator.share || !navigator.canShare({ files: [f] })) return 'unsupported';
        await navigator.share({ files: [f], text: text });
        return 'shared';
      } catch (e) {
        return e && e.name === 'AbortError' ? 'cancelled' : 'unsupported';
      }
    },
    save: function (bytes, name, mime) {
      try {
        var url = URL.createObjectURL(new Blob([bytes], { type: mime }));
        var a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
        return true;
      } catch (e) {
        return false;
      }
    },
  };
})();
