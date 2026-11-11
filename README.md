# Al Rashedy POS — desktop terminal

Offline-first Windows cashier client for the Django ERP in `Z:\Elrashedy`.
It reuses the existing POS server logic through a thin token-authenticated API, so the
browser terminal at `/factory/pos/` keeps working unchanged.

- Arabic RTL UI, same palette and workflow as the web POS.
- Sales are written to a local SQLite outbox first, then synced. The terminal keeps
  selling when the internet drops.
- Thermal receipts are rendered with Flutter's text engine (correct Arabic shaping) and
  sent as ESC/POS raster — over TCP, through the Windows USB spooler, or as PDF/A4.

## Requirements

- Windows 10/11 x64 for the installed app.
- Flutter 3.47.9 (stable) + Visual Studio 2022 "Desktop development with C++" to build locally.
- The Django server with the `pos_api` app migrated.

## Django side

```bash
python manage.py migrate pos_api
```

`POS_DESKTOP_REPO` (env var, default `K-AlRashedy/ElrashedyPOS`) tells the server which
GitHub repo publishes the installer. Set it on Heroku to the real repo:

```bash
heroku config:set POS_DESKTOP_REPO=<owner>/<repo>
```

Endpoints added under `/pos-api/v1/`: `auth/login`, `auth/logout`, `bootstrap`,
`catalog/<branch_id>`, `sync`, `shift/summary`, `shift/expenses`, `shift/expense`,
`shift/advance`, `shift/supplier-payment`, `shift/close`, `app/latest`.

Website download page: **`/pos/download/`** — linked from the sidebar under
"كاشير المطعم" as "تحميل كاشير سطح المكتب". It resolves the newest GitHub release and
redirects `/pos/download/latest/` straight to the installer.

Device tokens are issued at login, stored SHA-256 hashed, and revoked on logout.
The desktop app keeps the raw token in Windows DPAPI via `flutter_secure_storage`.

## Build and release locally

```bash
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

To prepare a distributable package from Windows, install Flutter (stable) and Inno
Setup 6, then run this from the project root:

```powershell
.installer\build.ps1
```

The script resolves dependencies, runs `flutter analyze` and `flutter test`, builds
the Windows release, creates a portable zip, and creates the Inno Setup installer in
`dist\`. To build only the portable zip, use `-PortableOnly`; to package a specific
version, use `-Version 1.0.1`. `-SkipChecks` is available for a faster local package
after validation has already passed.

Installer (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)):

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.0.0 installer\pos.iss
```

Output lands in `dist\ElrashedyPOS-Setup-1.0.0.exe`.

## CI

`.github/workflows/build-windows.yml` runs analyze + tests + a release build on every push
and PR, and packages both the installer and a portable zip. Pushing a `v*` tag publishes
them to GitHub Releases, which is what `/pos/download/` and the in-app update check read.

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow pins Flutter 3.47.9 — bump it together with `pubspec.yaml`'s SDK constraint.

## Using the terminal

1. Launch, enter the server URL (e.g. `https://your-app.herokuapp.com`), cashier username
   and password. The device name is optional and shows up in the token registry.
2. Pick the branch in the top bar.
3. Open **الطابعات** (F10) and configure each printer:
   - **شبكة (TCP)** — printer IP + port 9100. Fastest path, no driver involved.
   - **USB (Windows)** — pick the installed printer; bytes go to the spooler as `RAW`.
   - **PDF / A4** — fallback for laser printers or archiving.
   Set 80mm or 58mm paper, then press **طباعة تجريبية**.
4. Sell. Customer receipt and kitchen ticket print automatically if enabled.

If the server is unreachable at startup the app restores the cached session and menu and
shows an offline warning; queued tickets sync automatically once it is back.

### Shortcuts

| Key | Action |
| --- | --- |
| `Ctrl+F` | Focus product search (Enter adds the first match) |
| `F2` | Order details (dine-in / takeaway / delivery) |
| `F3` | Reprint kitchen ticket |
| `F4` | Shift expense |
| `F6` | Employee advance |
| `F7` | Supplier payment |
| `F8` | Refresh menu, shift and sync |
| `F9` | Ticket history / reprint |
| `F10` | Printer settings |
| `F12` | Open cash drawer |

Barcode scanning is not implemented: `pos_menu` does not expose a barcode field. Search
plus Enter covers the same flow.

## Layout

```
lib/core/       API client, models, money math, SQLite outbox, sync engine
lib/printing/   ESC/POS builder, Arabic raster renderer, TCP + spooler + PDF transports
lib/state/      AppState, CartState, ShiftState, PrinterState (ChangeNotifier)
lib/ui/         Terminal, login, printer settings, dialogs and widgets
installer/      Inno Setup script
test/           Money, dates, tickets, ESC/POS, raster, API and model tests
```

## Tests

```bash
flutter test
```

The raster tests load the real Cairo font and assert that Arabic text produces ink at both
paper widths, so shaping regressions fail the build.
