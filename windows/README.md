# SiekerCheck for Windows

The same checklist as the Mac build, in an Electron app: screen colours,
speakers, microphone, camera, keyboard, mouse, battery, drives and network, each
with a result that exports as a Markdown report.

```sh
cd windows
npm install
npm start          # run it
npm run dist       # build dist/SiekerCheck-Setup-1.0.0.exe
```

The installer chooses its own directory, adds a desktop and Start Menu
shortcut, and uninstalls from Apps & features. It is unsigned, so Windows
SmartScreen will warn on first run; choose More info then Run anyway.

## What is where

- `main.js` is the only OS-specific code: WMI queries through PowerShell for
  battery and drives, a disk speed test on the temp volume, and the Node facts.
  Everything is exposed to the page over IPC behind context isolation.
- `renderer/` is plain HTML, CSS and JavaScript using browser APIs, so the
  display, audio, microphone, camera, keyboard and pointer checks behave the
  same everywhere and can be developed in a browser.

Opening `renderer/index.html` directly in a browser works: the OS-facing calls
report themselves unavailable rather than taking the page down.

## Verification status

This was built on a Mac, and that is the honest limit of it:

- **Verified here:** every JavaScript file passes `node --check`; the produced
  `SiekerCheck-Setup-1.0.0.exe` is a genuine 64-bit PE32 Windows installer
  containing the app files in its asar; and the whole interface was driven in a
  browser, including colour cycling with Escape to exit, the guided pass
  advancing screen by screen, the keyboard check marking keys as pressed, the
  report Markdown, and results persisting.
- **Not verified:** nothing Windows-specific has ever been executed. The WMI
  battery and drive queries, the PowerShell path, the disk benchmark, and the
  installer itself have not run on Windows. Treat the first Windows run as the
  real test.

The Mac build lives one directory up.
