/* Fills the yellow info box with the environment details and keeps it current.
   iOS can apply the safe-area insets after the first script has run, so one read at parse time may report 0 even
   though the page ends up laid out with the real inset. The probe is not viewport-constrained (position: absolute),
   so it can't take part in WebKit's fixed-element detection at the top edge. */
(function () {
  var el = document.getElementById('mode');
  var probe = document.createElement('div');
  probe.style.cssText = 'position:absolute;top:0;left:0;width:0;height:env(safe-area-inset-top);visibility:hidden;pointer-events:none';
  document.body.appendChild(probe);

  function safeTop() { return Math.round(probe.getBoundingClientRect().height * 100) / 100; }
  var firstRead = safeTop();

  function render() {
    var top = safeTop();
    var mode = ['standalone', 'fullscreen', 'minimal-ui', 'browser'].filter(function (m) { return matchMedia('(display-mode: ' + m + ')').matches; })[0] || 'unknown';
    el.style.whiteSpace = 'pre-wrap';
    el.textContent =
      'status bar style: ' + document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]').content +
      '\ntoolbar: ' + (document.querySelector('.toolbar.solid') ? 'opaque background-color' : 'transparent over the status bar') +
      '\ndisplay-mode: ' + mode + ' · navigator.standalone: ' + navigator.standalone +
      '\nsafe-area-inset-top: ' + top + 'pt' + (top !== firstRead ? ' (' + firstRead + 'pt when the page first ran)' : '') +
      ' · devicePixelRatio: ' + devicePixelRatio +
      '\nwindow: ' + innerWidth + '×' + innerHeight + ' · screen: ' + screen.width + '×' + screen.height +
      '\n' + navigator.userAgent;
  }

  render();
  if (window.ResizeObserver) new ResizeObserver(render).observe(probe);
  ['load', 'pageshow', 'resize', 'orientationchange'].forEach(function (type) { addEventListener(type, render); });
})();
