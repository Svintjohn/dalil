/* Tells the app which Islamic month and day it is, for the Ramadan and Eid decorations.
   Returns "month-day" such as "9-14", or "" when the browser cannot work it out. */
(function () {
  'use strict';
  window.dalilHijri = function (ms) {
    try {
      var parts = new Intl.DateTimeFormat('en-u-ca-islamic-umalqura', { month: 'numeric', day: 'numeric' }).formatToParts(new Date(ms));
      var m = '', d = '';
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === 'month') m = parts[i].value;
        if (parts[i].type === 'day') d = parts[i].value;
      }
      return /^\d+$/.test(m) && /^\d+$/.test(d) ? m + '-' + d : '';
    } catch (e) {
      return '';
    }
  };
})();
