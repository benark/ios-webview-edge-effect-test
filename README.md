# ios-webview-edge-effect-test

Testing an issue in the iOS WebView edge effect, with reproductions of said issue.

## The issue

On iOS 27, a web app opened from the Home Screen with `apple-mobile-web-app-status-bar-style` set to
`black-translucent` and `viewport-fit=cover` gets the system's top scroll edge effect (a progressive blur and fade)
from the top of the screen to about 35 pt below the status bar. That band covers `position: fixed` toolbars placed
just under the status bar, and the page has no way to prevent it. It is tracked as
[WebKit bug 324438](https://bugs.webkit.org/show_bug.cgi?id=324438).

## What this repository tests

A web page cannot change the edge effect; only the native app that hosts the web view can. `App/` is a small app that
stands in for the Home Screen web app shell: a full-screen `WKWebView` that loads a reproduction page and applies one
setting to `webView.scrollView.topEdgeEffect`. The workflow runs it in an iOS simulator and takes a screenshot of each
case:

| Case | Page | Edge effect | Scrolled |
|---|---|---|---|
| `automatic-top` | toolbar transparent over the status bar | default | no |
| `automatic-scrolled` | same | default | yes |
| `soft-top` | same | `.soft` | no |
| `soft-scrolled` | same | `.soft` | yes |
| `hard-top` | same | `.hard` | no |
| `hard-scrolled` | same | `.hard` | yes |
| `hard-solid-top` | opaque toolbar from the top of the screen | `.hard` | no |
| `hidden-top` | toolbar transparent over the status bar | hidden | no |

`automatic-top` is the check that the stand-in is valid: it should show the same band as the Home Screen web app on a
real iPhone (sharp from about 97 pt on an iPhone 18 Pro Max). The `hard` cases answer the question this was built for:
does the hard style keep the effect inside the status bar area?

## Running it

Actions tab → **Edge effect test** → **Run workflow**. Each run:

- saves the screenshots and a text report per case in a `run-N` folder on the
  [`results`](../../tree/results) branch, and
- attaches the same files to the run as the `screenshots` artifact.

To run it on a Mac: `scripts/build.sh && scripts/run.sh` (Xcode 27 with an iOS 27 simulator).

## Reading a screenshot

The pages have a red ruler on the left edge marked in points from the top of the screen, and a toolbar of fine test
patterns (rings, a 2 px checkerboard, small text). Find where the ruler's tick marks become sharp: that is where the
effect ends. Each report lists the page's own readout (`safe-area-inset-top`, window size) and the web view's insets.

## Limits

- This is a simulator, not a device, and a plain `WKWebView`, not Apple's Home Screen shell. `automatic-top` has to
  match a device screenshot before the other cases mean anything.
- The pages load from the live site, so a run needs network access.
