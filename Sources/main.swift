import AppKit
import WebKit

// Tubemac: a lightweight, unofficial YouTube Music app for macOS.
// Not affiliated with, endorsed by or sponsored by Google LLC.

private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Tubemac"
private let isGerman = Locale.preferredLanguages.first?.hasPrefix("de") ?? false
private func L(_ english: String, _ german: String) -> String { isGerman ? german : english }

private let homeURL = URL(string: "https://music.youtube.com/")!

/// `--url https://music.youtube.com/…` opens a specific page on launch.
private let startURL: URL = {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--url"), i + 1 < args.count,
          let url = URL(string: args[i + 1]), url.host == "music.youtube.com" else { return homeURL }
    return url
}()
// Google blocks sign-in from "embedded browsers"; a plain Safari UA avoids that.
private let safariUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

/// Hosts that stay inside the app; user-clicked links elsewhere open in the default browser.
private func isInternalHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else { return true }
    let suffixes = ["youtube.com", "youtu.be", "google.com", "gstatic.com", "googleusercontent.com", "ytimg.com", "ggpht.com"]
    if suffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return true }
    // Regional Google sign-in domains (accounts.google.de, …)
    return host.hasPrefix("accounts.google.")
}

// YouTube Music's nav bar height; the traffic lights are centered in it.
private let navBarHeight: CGFloat = 64
private let trafficLightsInset: CGFloat = 20

// Runs before the page's own code.
// - WebKit publishes the page's Media Session as the system "Now Playing" entry. YouTube Music
//   registers seek ±10 s handlers, which macOS shows as skip buttons instead of previous/next.
//   Dropping those and making sure previous/next/seek-to exist gives Apple-Music-like controls.
// - Disables the rubber-band overscroll so the UI stays pinned to the window.
// - The page runs under the transparent titlebar: makes room for the traffic lights in the
//   nav bar and lets its empty areas drag the window like a titlebar.
private let earlyScript = """
(() => {
  const TRAFFIC_LIGHTS_WIDTH = 80;  // inset + three buttons, shifts the nav bar content right
  const TITLEBAR_HEIGHT = 32;
  const style = document.createElement('style');
  style.textContent = `
    html, body { overscroll-behavior: none !important; }
    html:not(.ytm-native-fullscreen) ytmusic-nav-bar #left-content { margin-left: ${TRAFFIC_LIGHTS_WIDTH}px !important; }
    ytmusic-nav-bar .center-content {
      position: absolute !important; left: 0 !important; right: 0 !important;
      margin: 0 auto !important; padding-left: 0 !important; transform: none !important;
      width: clamp(240px, calc(100vw - 600px), 480px) !important; justify-content: center;
    }
    ytmusic-nav-bar ytmusic-search-box { width: 100% !important; max-width: none !important; margin: 0 !important; }
    ytmusic-nav-bar #right-content { margin-left: auto !important; }
  `;
  (document.head || document.documentElement).appendChild(style);

  const interactive = 'a, button, input, textarea, select, [role=button], [role=link], [contenteditable], '
    + 'yt-icon-button, tp-yt-paper-icon-button, ytmusic-search-box, ytmusic-logo';
  window.addEventListener('mousedown', (e) => {
    if (e.button !== 0 || document.documentElement.classList.contains('ytm-native-fullscreen')) return;
    const t = e.target;
    if (!(t instanceof Element) || t.closest(interactive)) return;
    const inNavBar = !!t.closest('ytmusic-nav-bar') || t.id === 'nav-bar-background';
    if (!inNavBar && e.clientY > TITLEBAR_HEIGHT) return;
    window.webkit.messageHandlers.windowDrag.postMessage(e.detail);
  }, true);

  const ms = navigator.mediaSession;
  if (!ms || ms.__ytmWrapped) return;
  ms.__ytmWrapped = true;
  const set = ms.setActionHandler.bind(ms);
  const trySet = (action, handler) => { try { set(action, handler); } catch (e) {} };
  const dropped = new Set(['seekbackward', 'seekforward']);
  ms.setActionHandler = (action, handler) => trySet(action, dropped.has(action) ? null : handler);

  const click = (sel) => () => { const b = document.querySelector(sel); if (b) b.click(); };
  trySet('previoustrack', click('ytmusic-player-bar .previous-button'));
  trySet('nexttrack', click('ytmusic-player-bar .next-button'));
  trySet('seekto', (d) => {
    const v = document.querySelector('video');
    if (v && d.seekTime != null) v.currentTime = d.seekTime;
  });
})();
"""

// Observes the page's player and exposes controls for the native side.
private let bridgeScript = """
(() => {
  if (window.__ytmBridge) return;
  window.__ytmBridge = true;
  let last = '';
  const video = () => document.querySelector('video');
  function push(force) {
    const v = video();
    const md = navigator.mediaSession && navigator.mediaSession.metadata;
    const s = {
      title: md ? (md.title || '') : '',
      artist: md ? (md.artist || '') : '',
      playing: !!(v && !v.paused && !v.ended),
    };
    const key = JSON.stringify(s);
    if (!force && key === last) return;
    last = key;
    window.webkit.messageHandlers.nowPlaying.postMessage(s);
  }
  setInterval(() => push(false), 1000);
  ['play', 'pause', 'seeked', 'loadedmetadata', 'ended'].forEach((e) =>
    document.addEventListener(e, () => push(true), true));

  const click = (sel) => { const b = document.querySelector(sel); if (b) { b.click(); return true; } return false; };
  window.__ytm = {
    toggle() {
      if (!click('ytmusic-player-bar #play-pause-button')) {
        const v = video(); if (v) { v.paused ? v.play() : v.pause(); }
      }
    },
    play() { const v = video(); if (v && v.paused) this.toggle(); },
    pause() { const v = video(); if (v && !v.paused) this.toggle(); },
    next() { click('ytmusic-player-bar .next-button'); },
    previous() { click('ytmusic-player-bar .previous-button'); },
  };
})();
"""

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
    WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler
{
    private var window: NSWindow!
    private var webView: WKWebView!
    private var isPlaying = false
    private var lastMouseDown: NSEvent?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        webView.load(URLRequest(url: startURL))
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window

    private func buildWindow() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // persistent cookies → stay signed in
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.add(self, name: "nowPlaying")
        config.userContentController.add(self, name: "windowDrag")
        config.userContentController.addUserScript(
            WKUserScript(source: earlyScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(
            WKUserScript(source: bridgeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUserAgent
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.isInspectable = true
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = appName
        window.appearance = NSAppearance(named: .darkAqua)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedWhite: 0.012, alpha: 1)
        window.minSize = NSSize(width: 760, height: 480)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = webView
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeKeyAndOrderFront(nil)
        layoutTrafficLights()

        // performDrag needs the original mouse-down; the page reports drags asynchronously.
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.lastMouseDown = event
            return event
        }
    }

    // MARK: - Titlebar

    /// Centers the traffic lights in the page's nav bar. AppKit resets them on every
    /// titlebar layout, so this runs again after resizes and state changes.
    private func layoutTrafficLights() {
        guard !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let mini = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview, let container = titlebar.superview else { return }
        var frame = container.frame
        frame.size.height = navBarHeight
        frame.origin.y = window.frame.height - navBarHeight
        container.frame = frame
        titlebar.frame = container.bounds
        let spacing = mini.frame.minX - close.frame.minX
        for (i, button) in [close, mini, zoom].enumerated() {
            button.setFrameOrigin(NSPoint(x: trafficLightsInset + CGFloat(i) * spacing,
                                          y: (navBarHeight - button.frame.height) / 2))
        }
    }

    func windowDidResize(_ notification: Notification) { layoutTrafficLights() }
    func windowDidBecomeKey(_ notification: Notification) { layoutTrafficLights() }
    func windowDidResignKey(_ notification: Notification) { layoutTrafficLights() }

    func windowWillEnterFullScreen(_ notification: Notification) { setFullScreenClass(true) }
    func windowDidExitFullScreen(_ notification: Notification) {
        setFullScreenClass(false)
        layoutTrafficLights()
    }

    private func setFullScreenClass(_ on: Bool) {
        webView.evaluateJavaScript(
            "document.documentElement.classList.toggle('ytm-native-fullscreen', \(on))", completionHandler: nil)
    }

    private func handleWindowDrag(clickCount: Int) {
        guard let event = lastMouseDown else { return }
        if clickCount >= 2 {
            // Same behavior as double-clicking a titlebar (System Settings → Desktop & Dock).
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window.miniaturize(nil)
            case "None": break
            default: window.zoom(nil)
            }
        } else if NSEvent.pressedMouseButtons & 1 != 0 {
            window.performDrag(with: event)
        }
    }

    // Closing the window only hides it so music keeps playing.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @objc private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: isPlaying ? L("Pause", "Pause") : L("Play", "Wiedergabe"), action: #selector(playPause), keyEquivalent: "")
        menu.addItem(withTitle: L("Next Track", "Nächster Titel"), action: #selector(nextTrack), keyEquivalent: "")
        menu.addItem(withTitle: L("Previous Track", "Vorheriger Titel"), action: #selector(previousTrack), keyEquivalent: "")
        return menu
    }

    // MARK: - Menu

    private func buildMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About \(appName)", "Über \(appName)"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: L("Support \(appName) …", "\(appName) unterstützen …"), action: #selector(openDonation), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Hide \(appName)", "\(appName) ausblenden"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: L("Hide Others", "Andere ausblenden"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("Show All", "Alle einblenden"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit \(appName)", "\(appName) beenden"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, title: appName, to: main)

        let edit = NSMenu(title: L("Edit", "Bearbeiten"))
        edit.addItem(withTitle: L("Undo", "Widerrufen"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("Redo", "Wiederholen"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Cut", "Ausschneiden"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copy", "Kopieren"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Paste", "Einsetzen"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Select All", "Alles auswählen"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Copy Page URL", "Aktuelle URL kopieren"), action: #selector(copyURL), keyEquivalent: "C")
        addSubmenu(edit, title: L("Edit", "Bearbeiten"), to: main)

        let view = NSMenu(title: L("View", "Darstellung"))
        view.addItem(withTitle: L("Home", "Startseite"), action: #selector(goHome), keyEquivalent: "H")
        view.addItem(withTitle: L("Reload", "Neu laden"), action: #selector(reload), keyEquivalent: "r")
        view.addItem(withTitle: L("Back", "Zurück"), action: #selector(goBack), keyEquivalent: "[")
        view.addItem(withTitle: L("Forward", "Vorwärts"), action: #selector(goForward), keyEquivalent: "]")
        view.addItem(.separator())
        view.addItem(withTitle: L("Zoom In", "Vergrößern"), action: #selector(zoomIn), keyEquivalent: "+")
        view.addItem(withTitle: L("Zoom Out", "Verkleinern"), action: #selector(zoomOut), keyEquivalent: "-")
        view.addItem(withTitle: L("Actual Size", "Originalgröße"), action: #selector(zoomReset), keyEquivalent: "0")
        view.addItem(.separator())
        let fs = view.addItem(withTitle: L("Enter Full Screen", "Vollbild"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fs.keyEquivalentModifierMask = [.command, .control]
        addSubmenu(view, title: L("View", "Darstellung"), to: main)

        let playback = NSMenu(title: L("Playback", "Wiedergabe"))
        playback.addItem(withTitle: L("Play/Pause", "Wiedergabe/Pause"), action: #selector(playPause), keyEquivalent: "p")
        let next = playback.addItem(withTitle: L("Next Track", "Nächster Titel"), action: #selector(nextTrack), keyEquivalent: String(UnicodeScalar(NSRightArrowFunctionKey)!))
        next.keyEquivalentModifierMask = [.command]
        let prev = playback.addItem(withTitle: L("Previous Track", "Vorheriger Titel"), action: #selector(previousTrack), keyEquivalent: String(UnicodeScalar(NSLeftArrowFunctionKey)!))
        prev.keyEquivalentModifierMask = [.command]
        addSubmenu(playback, title: L("Playback", "Wiedergabe"), to: main)

        let account = NSMenu(title: L("Account", "Konto"))
        account.addItem(withTitle: L("Open Passwords App", "Passwörter-App öffnen"), action: #selector(openPasswordsApp), keyEquivalent: "")
        addSubmenu(account, title: L("Account", "Konto"), to: main)

        let win = NSMenu(title: L("Window", "Fenster"))
        win.addItem(withTitle: L("Minimize", "Im Dock ablegen"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: L("Zoom", "Zoomen"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        win.addItem(withTitle: L("Close Window", "Fenster schließen"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        win.addItem(.separator())
        win.addItem(withTitle: appName, action: #selector(showWindow), keyEquivalent: "1")
        addSubmenu(win, title: L("Window", "Fenster"), to: main)
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }

    private func addSubmenu(_ submenu: NSMenu, title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        submenu.title = title
        item.submenu = submenu
        menu.addItem(item)
    }

    @objc private func goHome() { webView.load(URLRequest(url: homeURL)) }
    @objc private func reload() { webView.reload() }
    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func zoomIn() { webView.pageZoom = min(webView.pageZoom + 0.1, 3) }
    @objc private func zoomOut() { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    @objc private func zoomReset() { webView.pageZoom = 1 }
    @objc private func copyURL() {
        guard let url = webView.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    // MARK: - Playback

    @objc private func playPause() { run("toggle()") }
    @objc private func nextTrack() { run("next()") }
    @objc private func previousTrack() { run("previous()") }

    private func run(_ call: String) {
        webView.evaluateJavaScript("window.__ytm && window.__ytm.\(call)", completionHandler: nil)
    }

    nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            if message.name == "windowDrag" {
                handleWindowDrag(clickCount: message.body as? Int ?? 1)
                return
            }
            guard message.name == "nowPlaying", let info = message.body as? [String: Any] else { return }
            isPlaying = info["playing"] as? Bool ?? false
        }
    }

    // MARK: - Account

    @objc private func openDonation() {
        NSWorkspace.shared.open(URL(string: "https://www.paypal.com/paypalme/morrret")!)
    }

    @objc private func openPasswordsApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Passwords.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    // MARK: - Navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, action.navigationType == .linkActivated,
           action.targetFrame?.isMainFrame ?? true, !isInternalHost(url.host) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // target="_blank" / window.open
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if isInternalHost(url.host) { webView.load(action.request) } else { NSWorkspace.shared.open(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: L("Cancel", "Abbrechen"))
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if window.styleMask.contains(.fullScreen) { setFullScreenClass(true) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
