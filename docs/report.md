# iOS Home Screen web apps: the top edge blur covers fixed toolbars below the status bar (`black-translucent`)

A report for Apple (Feedback Assistant) and WebKit (bugs.webkit.org), with a live reproduction.

On bugs.webkit.org this behavior is already tracked as [bug 324438](https://bugs.webkit.org/show_bug.cgi?id=324438)
(see [Related reports](#related-reports)). A new bug there would most likely be closed as a duplicate, as bug 328168
was, so add this reproduction as a comment on 324438 instead. File it in Feedback Assistant separately.

## Summary

In a web app opened from the Home Screen with
`<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">` and `viewport-fit=cover`, iOS 27
draws its top scroll edge effect (a progressive blur and fade) from the top of the screen to about 35 pt **below the
status bar**. It covers `position: fixed` toolbars placed just under the status bar (like an app's navigation bar),
even when nothing is scrolled, although they sit entirely inside the area that `env(safe-area-inset-top)` reports as
safe. The page has no way to turn the effect off: giving the toolbar an opaque background from the top of the screen
changes nothing. The same page in Safari keeps the fixed toolbar sharp, and the same page with `content="default"` is
sharp everywhere.

The effect is useful over the status bar itself, where it keeps the time, Dynamic Island and status icons legible and
apart from page content. The problem is only the part that extends below it.

## Live reproduction

- Bug: https://benark.github.io/ios-webview-edge-effect-test/translucent/ (`black-translucent`; the toolbar is
  transparent over the status bar)
- Control: https://benark.github.io/ios-webview-edge-effect-test/default/ (`default`)
- Opaque toolbar: https://benark.github.io/ios-webview-edge-effect-test/translucent-solid/ (`black-translucent`; the
  toolbar has a plain white `background-color` from the top of the screen)

Each page is a single static HTML file plus a small manifest, stylesheet and script (in [`repro/`](../repro) in this
repository), with a fixed toolbar of high-frequency test patterns (concentric rings, a 2 px checkerboard, 1 px lines, small text),
the same patterns at the top of the scrolling content, a red ruler marking points from the top of the screen, and an
info box with the environment details. The stylesheet has no `filter`, `backdrop-filter`, `mask` or `opacity`. The Bug
and Control pages differ only in the status bar meta tag, the app title and the instruction text.

## Steps

1. On an iPhone running iOS 27, open the **Bug** URL in Safari. Note that the toolbar and first content block are
   sharp.
2. Share → Add to Home Screen. Open "Fade Bug" from the Home Screen.
3. Look at the fixed toolbar against the ruler, from the status bar down to about 35 pt below it.
4. Repeat steps 1–3 with the **Control** URL ("Fade Ctrl") and the **Opaque toolbar** URL ("Fade Solid"), and
   compare.

## Expected

The effect covers the status bar inset, where it protects the system indicators, and stops there. A fixed toolbar
that sits entirely below the status bar renders sharp, as it does in Safari and in the `default` (control) app. Native
apps already get this: their bar controls are separate views above the effect.

## Actual

Measured on the four screenshots in [`docs/device/`](device) (iPhone 18 Pro Max, 440 × 956 pt), opened from the Home
Screen. The first three are unscrolled:

- "Fade Bug": `env(safe-area-inset-top)` is 62 pt and the web view covers the whole screen. The ruler's 1 pt tick
  marks have no measurable contrast from 0 to about 50 pt, and are also faded about 70% toward the page color there.
  Contrast returns between about 54 and 97 pt (5% at 70 pt, 35% at 80 pt, 65% at 90 pt, 100% from 97 pt). The toolbar
  row runs from 62 to 118 pt, so its upper 35 pt is soft: the first label line, the top of the rings and the top of
  both buttons.
- "Fade Solid": the same. Its screenshot matches "Fade Bug" to within 1/255 per channel all the way down to the info
  box, so an opaque fixed toolbar at the top edge neither hides nor changes the effect.
- "Fade Ctrl" (`default`): the web view starts 62 pt down, below a solid status bar, and everything is sharp.
- Below the toolbar (from 128 pt) the three screenshots are identical pixel for pixel, apart from the text that
  differs between the pages. So with nothing scrolled, the scrolling content is not affected; it is blurred when it
  scrolls into the band.
- "Fade Bug" scrolled (fourth screenshot): the band is the same height. The ruler profile matches the unscrolled one
  to within 2 percentage points and is sharp from 97 pt. Content passing under the status bar is blurred and faded,
  so the indicators stay readable; that part works as intended.
- In Safari (not installed), the fixed toolbar is sharp with either value.

## Analysis

From reading WebKit `main` (November 2026); not confirmed with a debugger.

- The effect is UIKit's top scroll edge effect on the web view's scroll view (WebKit calls it the top scroll pocket).
  Fixed-position content is drawn inside that scroll view, so the effect covers it. A native app's navigation bar is
  a separate view above its scroll view.
- WebKit hides the effect only through `-[WKWebView _shouldHideTopScrollPocket]`
  (`Source/WebKit/UIProcess/API/ios/WKWebViewIOS.mm`), which returns
  `[self _hasVisibleColorExtensionView:WebCore::BoxSide::Top]`.
- `-[WKWebView _updateFixedColorExtensionViews]` (`Source/WebKit/UIProcess/API/Cocoa/WKWebView.mm`) fades that view
  out when `insets.at(side) <= 0 || !_fixedContainerEdges.hasFixedEdge(side)`. The insets are the web view's obscured
  insets, which the embedding app sets.
- In Safari, and in a `default` Home Screen app, the status bar is a top obscured inset. A fixed or sticky element at
  the top edge (`LocalFrameView::fixedContainerEdges()`) then gets a color extension view, and the effect is hidden.
- An edge-to-edge (`black-translucent`) Home Screen app appears to have no top obscured inset, so the first condition
  always fails and the effect can never be hidden, whatever the page puts at the top edge. The Home Screen web app
  shell is not open source, so the missing inset is inferred. The device result fits it: the toolbar in "Fade Solid"
  is the kind of element this code looks for (fixed, full width, opaque `background-color`), and the effect stays.
- The band is what UIKit's `soft` style draws, not the iOS 27 default. A test app with a full-screen `WKWebView` and
  no obscured inset ([`App/`](../App) in this repository), run in the iOS 27.2 simulator (iPhone 18 Pro Max), loads
  the "Fade Bug" page with each style. The screenshots are on the
  [`results`](https://github.com/benark/ios-webview-edge-effect-test/tree/results) branch and summarized in the
  [README](../README.md#results).
  - `automatic` (the default) and `hard` both end at 62 pt, the bottom of the top safe area inset. From there down,
    their screenshots are identical pixel for pixel to one taken with the effect hidden, and the toolbar is sharp.
    Content scrolled under the status bar is still blurred.
  - `soft` shows the ruler from 72 pt and sharp from 96 pt, exactly as the Home Screen web app does on the device,
    and the contrast in between agrees to within 5 percentage points.
  - So Home Screen web apps appear to run with the soft style. That is inferred from the match; the shell's code is
    not public.
- iOS 27 changed the default style. From WWDC26 session 278,
  [Modernize your UIKit app](https://developer.apple.com/videos/play/wwdc2026/278/): "the .automatic style no longer
  switches between the existing soft and hard styles but provides its own visuals for additional clarity. If you have
  overridden the style from .automatic previously, that decision should be re-evaluated, especially when set to .soft,
  as that no longer matches the default system appearance."

## Suggested fix

Not built or tested. The WebKit parts are from reading WebKit `main`.

The effect is worth keeping where it protects the system indicators, and this report does not ask for it to be
removed. The defect is its extent: it reaches about 35 pt past the top safe area inset, into the area the page is told
is safe. A native app's bar controls are separate views above the effect; a web page's fixed toolbar is inside the
scroll view, so it has no way to get above it.

### 1. Keep the effect inside the system area (preferred)

Give Home Screen web apps the iOS 27 default (`automatic`) style, or the `hard` style, for the top edge effect in
place of the soft style they appear to use now. Both are public API on the web view's scroll view
(`webView.scrollView.topEdgeEffect.style`). In the simulator test described under Analysis, both end the effect at
the bottom of the top safe area inset (62 pt on this device) and still blur content that scrolls under the status bar:

- `automatic` fades out between about 42 and 60 pt.
- `hard` has a cutoff with a dividing line at 62 pt. UIKit documents it as "A scroll edge effect with a hard cutoff
  and dividing line", and WWDC25 session 284,
  [Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/), recommends it "for
  denser UIs with a lot of floating elements", which describes a toolbar directly under the status bar.

The indicators stay protected, nothing in the page's safe area is touched, and it needs no guess about what the page
has put at the top. It also covers pages with no fixed element there (bug 328949), and it follows Apple's own WWDC26
guidance about the soft style, quoted under Analysis. The test ran in a simulator, not on a device.

The shell is not in the WebKit repository. Bug [300445](https://bugs.webkit.org/show_bug.cgi?id=300445), about another
Home Screen web app layout change, was moved out of WebKit as "an issue in Safari, not in WebKit".

### 2. Hide the effect when an opaque fixed element covers the top edge (WebKit only)

Narrower than fix 1, but it can be done entirely in WebKit, and it is what Safari already does for the same element.
The protection is kept: the indicators then sit on the element's own solid color, as they do on Safari's color fill.

Two conditions prevent it today in an edge-to-edge web view, and both depend on a top obscured inset:

1. Web process: `WebPage::sidesRequiringFixedContainerEdges()` (`Source/WebKit/WebProcess/WebPage/Cocoa/WebPageCocoa.mm`)
   adds `BoxSide::Top` only when `obscuredInsets.top() > 0`, so the top edge is never checked for fixed elements.
2. UI process: `_shouldHideTopScrollPocket` only looks at the top color extension view, which is never shown without
   a top obscured inset because there is nothing for it to fill.

Treat a top safe area inset that the page draws into the same way:

```cpp
// WebPage::sidesRequiringFixedContainerEdges()
#if PLATFORM(IOS_FAMILY)
    // Edge-to-edge web view: no top obscured inset, but UIKit still draws the top scroll edge effect over the
    // safe area inset.
    if (m_page->unobscuredSafeAreaInsets().top() > 0)
        sides.add(BoxSide::Top);
#endif
```

```objc
// -[WKWebView _shouldHideTopScrollPocket], replacing the final return
    if ([self _hasVisibleColorExtensionView:WebCore::BoxSide::Top])
        return YES;

    // With no top obscured inset there is no color extension view to show. An opaque fixed or sticky element that
    // covers the top edge already gives the system indicators a solid background, so the effect adds nothing there
    // and only blurs the element.
    return _obscuredInsets.top <= 0 && topFixedEdgeHasOpaqueBackgroundColor;
```

`topFixedEdgeHasOpaqueBackgroundColor` is new state. `LocalFrameView::fixedContainerEdges()` finds the element's own
background color (`primaryBackgroundColorForRenderer`) but falls back to sampling pixels when there is none, and
`FixedContainerEdges` does not record which it was, so the web process would have to report it.
`-_updateFixedContainerEdges:` already calls `-_updateHiddenScrollPocketEdges`, so the effect would hide and return as
the element comes and goes. `-_setObscuredInsetsInternal:` would need to call it too when the top inset changes
between zero and nonzero.

Result: "Fade Solid" becomes sharp. "Fade Bug", whose toolbar is transparent over the status bar, keeps the effect,
because content there still needs it. That case needs fix 1.

### 3. A documented control for web content

A viewport or manifest key, or a CSS property, that lets a page choose the edge effect style or keep it within the
safe area inset.

## Related reports

- [324438](https://bugs.webkit.org/show_bug.cgi?id=324438) "REGRESSION (iOS 27): PWA blurry in header/status bar"
  (NEW, rdar://187727574). [328168](https://bugs.webkit.org/show_bug.cgi?id=328168) was closed as its duplicate.
- [329103](https://bugs.webkit.org/show_bug.cgi?id=329103) (rdar://191690858),
  [330085](https://bugs.webkit.org/show_bug.cgi?id=330085) (rdar://192449901) and
  [328949](https://bugs.webkit.org/show_bug.cgi?id=328949) (rdar://191600024): the same blur, all NEW. 329103 says an
  opaque fixed bar at the top edge removes it; with `black-translucent` on iOS 27.2 it does not ("Fade Solid").
- [332418](https://bugs.webkit.org/show_bug.cgi?id=332418): the same configuration and the same source analysis as
  above. It says an opaque fixed strip did not remove the blur, which matches "Fade Solid".
- [317153](https://bugs.webkit.org/show_bug.cgi?id=317153), comment 2 (Luming Yin): "The black-translucent status bar
  mode has been deprecated for multiple releases ... Please remove this key ... Home Screen web apps does not support
  drawing arbitrary content below the status bar." This report is about a toolbar that is not under the status bar:
  it starts at `env(safe-area-inset-top)`.

As of November 22, 2026, the blur reports have Radar imports and one duplicate marking, but no reply about the
behavior from Apple.

## Notes

- The status bar style is read when the app is added to the Home Screen; changing the meta tag needs a re-add.
- Workaround: use `default`, or remove the meta tag (the page starts below an opaque status bar), at the cost of the
  edge-to-edge look.
- Found while building a phone-first web app that draws its own navigation bar just under the status bar.
- `scripts/measure.py` and `scripts/compare.py` reproduce the numbers in this report from the screenshots.

## Environment

- iPhone 18 Pro Max, 440 × 956 pt, `devicePixelRatio` 3.
- iOS 27.2, from `Version/27.2` in the user agent. Confirm the exact version and build in Settings → General → About.
- All three apps: `display-mode: standalone`, `navigator.standalone: true`, screen 440 × 956.
- `Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2
  Mobile/15E148 Safari/604.1`
- Info box readouts:

  | App | Status bar style | Toolbar | `safe-area-inset-top` | Window |
  |---|---|---|---|---|
  | Fade Bug | `black-translucent` | transparent over the status bar | 62 pt (0 pt when the page first ran) | 440 × 956 |
  | Fade Solid | `black-translucent` | opaque `background-color` | 62 pt | 440 × 956 |
  | Fade Ctrl | `default` | transparent over the status bar | 0 pt | 440 × 894 |

- On "Fade Bug" the inset read 0 pt when the page's first script ran and 62 pt afterward, so iOS can apply it after
  the page starts. On "Fade Solid" the first read was already 62 pt.
- The device screenshots were taken with the same page files served from another host, before they were published
  with GitHub Pages.
- Screenshots to attach, in [`docs/device/`](device): `fade-bug.png`, `fade-solid.png` and `fade-ctrl.png` (opened
  from the Home Screen, unscrolled) and `fade-bug-scrolled.png`.
