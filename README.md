<div align="center">

<img src="docs/assets/icon.png" width="128" height="128" alt="YTM Desktop icon">

# YTM Desktop – YouTube Music app for Mac

**Use your YouTube Music subscription as a real macOS app.**<br>
Free · open source · native Swift + WebKit · Apple Silicon & Intel · no tracking

[**⬇ Download for Mac**](https://github.com/claudimoret/youtube-music-mac/releases/latest/download/YTM-Desktop.zip) · [Website](https://claudimoret.github.io/youtube-music-mac/) · [Deutsch](#deutsch) · [♥ Support](#support)

<img src="docs/assets/screenshot-artist.png" alt="YTM Desktop: YouTube Music artist page in a native macOS window" width="900">

</div>

---

## Why?

There is no official YouTube Music app for macOS – only a browser tab that gets lost between twenty others, ignores the play button on your keyboard and stops when you close the wrong window.

**YTM Desktop** wraps the official web player (music.youtube.com) in a small native Mac app. Your library, playlists, mixes, lyrics and Premium work exactly like on the website, but it behaves like a music app should on a Mac.

## Features

- 🎹 **Media keys, AirPods & Touch Bar** – play/pause, next, previous, without browser extensions
- 🎛 **Clean Now Playing in Control Center** – artwork, previous / play / next and a scrubber, like Apple Music
- 🔁 **Background playback** – closing the window only hides it; click the Dock icon to bring it back
- 🖼 **Edge-to-edge design** – artwork and gradients run under the window buttons, centered search, no rubber-band scrolling
- 🔐 **Stays signed in** – sign in once with your Google account
- 🕶 **No tracking** – no analytics, no telemetry, no server of its own
- ⚡️ **Tiny & fast** – Apple's WebKit instead of a bundled Chromium, universal binary
- ⌨️ **Shortcuts** – ⌘P play/pause · ⌘→ / ⌘← next/previous · ⌘[ / ⌘] back/forward · ⌘R reload · ⌘+ / ⌘− zoom · ⌃⌘F full screen
- 🌍 **English and German menus** (follows your system language)

<p align="center">
  <img src="docs/assets/screenshot-album.png" alt="Album view" width="49%">
  <img src="docs/assets/screenshot-explore.png" alt="Explore view" width="49%">
</p>

## Install

1. **[Download YTM-Desktop.zip](https://github.com/claudimoret/youtube-music-mac/releases/latest/download/YTM-Desktop.zip)**, unzip it and move `YTM Desktop.app` to your **Applications** folder.
2. **Allow the first launch.** The app isn't notarized by Apple (that needs a paid developer account), so macOS blocks it once. Open **System Settings → Privacy & Security** and click **Open Anyway** – or run:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/YTM Desktop.app"
   ```
3. **Sign in** with your Google account (email + password). You stay signed in from now on.

Requires macOS 14 Sonoma or later.

### Build from source

```bash
git clone https://github.com/claudimoret/youtube-music-mac.git
cd youtube-music-mac
./build.sh --install
```

Needs Xcode or the Command Line Tools (`xcode-select --install`). The whole app is a single file: [`Sources/main.swift`](Sources/main.swift).

## FAQ

**Does it work with YouTube Music Premium?**<br>
Yes. You sign in with your own account, so Premium, your library, uploads and playlists are all there. Free accounts work too (with ads, like in the browser).

**Why can't I sign in with my passkey?**<br>
macOS only gives passkeys and Password AutoFill to Safari and to apps that Google has officially associated with its domain. On the Google sign-in page choose *Try another way → Enter your password*. You only need to do this once.

**Is it safe?**<br>
The app has no analytics and talks only to YouTube Music and Google sign-in. Links to other sites open in your default browser. Read the code – it's one file.

## How it works

A `WKWebView` loads music.youtube.com with a Safari user agent and a persistent website data store. A small injected script:

- passes YouTube Music's Media Session to macOS, replacing the ±10 s seek handlers with previous/next/seek-to so Control Center shows Apple-Music-style controls,
- disables overscroll and shifts the nav bar to make room for the traffic lights, which are centered in the 64 px nav bar,
- turns empty areas of the nav bar into a window drag region (double-click follows your titlebar setting).

---

<a name="deutsch"></a>

## 🇩🇪 Deutsch

**YouTube Music als echte Mac-App** – für alle, die ihr YouTube-Music-Abo auf dem Mac nicht im Browser-Tab nutzen wollen. Kostenlos, Open Source, ohne Tracking.

**Funktionen:** eigenes Dock-Icon und Fenster · Mediatasten, AirPods und Touch Bar · sauberer „Läuft gerade“-Eintrag im Kontrollzentrum mit Cover, Zurück/Weiter und Spulen · Musik läuft weiter, wenn das Fenster geschlossen ist · Design bis unter die Fensterknöpfe, Suche mittig · deutsche Menüs auf deutschen Systemen.

**Installation:**
1. [YTM-Desktop.zip herunterladen](https://github.com/claudimoret/youtube-music-mac/releases/latest/download/YTM-Desktop.zip), entpacken und in „Programme“ ziehen.
2. Beim ersten Start blockiert macOS die App einmal: **Systemeinstellungen → Datenschutz & Sicherheit → „Dennoch öffnen“**.
3. Mit dem Google-Konto anmelden. Fragt Google nach dem Passkey: **„Andere Option wählen“ → „Passwort eingeben“** (Passkeys funktionieren in Apps ohne Google-Freigabe nicht).

Voraussetzung: macOS 14 Sonoma oder neuer, Apple Silicon oder Intel.

---

<a name="support"></a>

## ♥ Support

YTM Desktop is free and made in my spare time. If you enjoy it, a small tip via PayPal is very welcome – totally optional.<br>
*Gefällt dir die App? Über eine kleine Spende freue ich mich – ganz freiwillig.*

[![Donate 1 €](https://img.shields.io/badge/Donate-1%20€-e8143c?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/paypalme/morrret/1EUR)
[![Donate 2 €](https://img.shields.io/badge/Donate-2%20€-e8143c?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/paypalme/morrret/2EUR)
[![Donate 5 €](https://img.shields.io/badge/Donate-5%20€-e8143c?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/paypalme/morrret/5EUR)
[![Other amount](https://img.shields.io/badge/Other%20amount-paypal.me%2Fmorrret-3a2a30?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/paypalme/morrret)

---

## License & disclaimer

MIT License – see [LICENSE](LICENSE).

YTM Desktop is an **unofficial** project. YouTube Music is a trademark of Google LLC. This app is not affiliated with, endorsed or sponsored by Google. It only displays the official YouTube Music website; use it in line with YouTube's Terms of Service.
