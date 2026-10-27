<img src="AppIcon.png" width="128" alt="ComprimiNote icon">

# ComprimiNote

**Collapses the folders in Apple Notes every time you open it.**

Apple Notes on the Mac reopens every time with every folder and subfolder expanded. With lots of folders the sidebar becomes endless. ComprimiNote is a small background app that, when Notes opens, collapses all the folders and subfolders in about two seconds. Account sections stay open.

It was built with [Claude Code](https://claude.com/claude-code).

---

## How it works

- It runs in the background, with no Dock icon, and consumes nothing until you open Notes. It reacts to the macOS "app opened" event, with no timers and no periodic checks.
- When Notes opens, it finds the sidebar and **presses the folder arrows exactly like a click**, from bottom to top: first the subfolders, then the main folders. That way, when you reopen a folder, the ones inside are closed too.
- It keeps checking for a couple of seconds, until the sidebar is stable. After that it doesn't touch Notes again until the next launch.

Why "press the arrows" and not something more direct: changing the rows' state directly is a little faster, but Notes doesn't notice, and when you rename a folder the sidebar flickers. With the arrows, Notes stays in sync.

## Privacy and security

ComprimiNote needs the **Accessibility** permission. It's a broad permission: macOS doesn't let you limit it to a single app. For this reason the code is designed to do as little as possible, and it's short (one file, under 300 lines) so anyone can read it.

**What it does:**
- It acts **only on the real Notes signed by Apple**. An app that names itself "Notes" without Apple's signature is ignored.
- Of Notes it reads only the sidebar structure: each row's level and whether it's open or closed.
- **It doesn't read** the content of your notes, nor the names of folders or accounts.
- It writes a log with times and counts only, for example `opened: collapsed 20 … 2109 ms`, in `~/Library/Application Support/ComprimiNote/log.txt`, readable only by you. The log refuses to write through links to other files.

**What it doesn't do:**
- No internet connection, no shell commands, no external files or scripts run.
- No simulated keystrokes or mouse events: it uses only the "press" action on the arrows.
- No data sent anywhere, no analytics.

**Protections:**
- It's signed with *hardened runtime*: macOS blocks injection of external code and attaching debuggers.
- Installed in `/Applications` with system ownership, so no program can modify it without your administrator password.
- If someone modifies the app, macOS no longer recognizes it and the permission stops working on its own.

## Installation

You need a Mac with **macOS 13 or later**. It should work on all of them, but it was tested only on macOS 27. You also need the Apple command line tools, which you can install with `xcode-select --install`.

There's no ready-made app to download: **you compile it yourself**, from the code you can read here. That way you know exactly what you're running.

```bash
git clone https://github.com/jrose7-hub/ComprimiNote.git
cd ComprimiNote
./build.sh       # compiles and signs build/ComprimiNote.app
./install.sh     # copies it to /Applications (asks for the password) and adds it to the login items
```

Then:

1. **System Settings › Privacy & Security › Accessibility** (on macOS 27: *Device control and data access*): turn on **ComprimiNote**.
2. Start it once: `open /Applications/ComprimiNote.app`. After that it starts on its own at login.
3. Quit Notes (⌘Q) and reopen it: the folders collapse.

### When you update it

Every rebuild produces a new app, and macOS ties the permission to the exact version. So after installing an update:

- in the permissions list, **remove** ComprimiNote with **–** and **add it again** with **+**, **after** installing;
- just turning the switch off and on isn't enough.

**Safety rule:** if ComprimiNote stops working on its own, without you having updated it, *don't re-grant the permission without thinking about it*. First check that the app's fingerprint matches what `build.sh` printed:

```bash
codesign -dv --verbose=4 /Applications/ComprimiNote.app 2>&1 | grep CDHash
```

## Uninstall

1. **System Settings › Privacy & Security › Accessibility**: remove ComprimiNote with **–**.
2. **System Settings › General › Login Items**: remove ComprimiNote.
3. In the Terminal:
   ```bash
   pkill -f ComprimiNote.app
   sudo rm -rf /Applications/ComprimiNote.app
   rm -rf ~/Library/Application\ Support/ComprimiNote
   ```

## Good to know

- It collapses the folders **when Notes opens**, not when you close the window with ⌘W and reopen it from the Dock.
- Notes takes about 1.8 seconds to finish loading, and before then it can't respond. That's why the collapse arrives about 2 seconds after opening, whatever the method.
- Sections such as **Tags** and the accounts are left alone. If you close them by clicking their header, Notes remembers that on its own.

## License

[MIT](LICENSE). Free to use, modify and share.
