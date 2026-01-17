# Disk Health Viewer (SMART)

![Platform](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white)
![Made with AutoIt](https://img.shields.io/badge/Made%20with-AutoIt-1f6feb)
![SMART](https://img.shields.io/badge/SMART-smartctl-0b7285)
![License](https://img.shields.io/badge/license-MIT-informational)

Portable disk health / SMART viewer for Windows, built with **AutoIt + smartctl + a small Python helper**.  
It shows a quick overview, health summary (warnings), and a SMART items table, and can export **TXT/HTML** reports or **copy a clean report to clipboard**.

---

## Features

- List physical disks (WMI)
- Read SMART via `smartctl` (supports SATA/SAS/NVMe)
- Overview: model, serial, temp, power-on hours, protocol, SMART health
- Health summary: Overall (OK/WARNING/BAD/UNKNOWN) + warnings list
- SMART Items table with Severity column (auto-sorted)
- Export:
  - **TXT** (raw helper output)
  - **HTML** (client-friendly report)
- **Copy Report** button (clipboard)

---

## Downloads

Grab the latest compiled release from the GitHub **Releases** page.

If you build from source, see the “Build / Development” section below.

---

## Requirements (for users)

- Windows 10/11
- Run as **Administrator** (recommended) for best SMART access
- The app is portable: no installer

### Folder structure (portable)

Put the EXE next to the `tools` folder like this:

```
DiskHealthViewer\
  DiskHealthViewer.exe
  DiskHealthViewer.ico
  tools\
    smartctl.exe
    smartread.py        (or smartread.exe)
    python\python.exe   (optional portable python)
```

**smartctl.exe is required.**  
The helper can be either:
- `tools\smartread.exe` (best: no Python required), OR
- `tools\smartread.py` (works with embedded python or system python)

---

## How to use

1. Right-click the app → **Run as administrator**
2. Click **Refresh** to list disks
3. Click a disk to select it
4. Click **Load SMART** (or double-click the disk)
5. Use:
   - **Copy Report** → paste into notes/email/tickets
   - **Export TXT** → saves raw helper output
   - **Export HTML** → saves a nice report for clients

---

## Troubleshooting

### “No SMART data” / “UNKNOWN”
- Run as **Administrator**
- Make sure `tools\smartctl.exe` exists
- Some USB enclosures don’t expose SMART properly. Try:
  - a different USB enclosure
  - direct SATA/NVMe connection
  - different smartctl device options (advanced users)

### The app can’t find Python
You have 3 options:

1) Recommended: build/use `tools\smartread.exe`  
2) Include embedded python: `tools\python\python.exe`  
3) Use system python installed in PATH

### Antivirus false positives
Portable tools that bundle executables sometimes trigger false positives (especially with AutoIt-packed binaries).  
Best practice:
- publish hashes (SHA-256) in Releases
- sign the EXE if you have a code signing cert
- keep sources public for transparency

---

## Build / Development (from source)

### Repo contents (typical)

```
DiskHealthViewer\
  DiskHealthViewer_v1.2.1.au3
  DiskHealthViewer.ico
  tools\
    smartctl.exe
    smartread.py
```

### 1) AutoIt (GUI app)

Requirements:
- AutoIt v3.3.16.1 (or compatible)
- SciTE / AutoIt3Wrapper (comes with AutoIt)

Steps:
1. Open `DiskHealthViewer_v1.2.1.au3`
2. Ensure the icon directive is set (optional but recommended):
   ```autoit
   #AutoIt3Wrapper_Icon=DiskHealthViewer.ico
   ```
3. (Optional) Set version metadata:
   ```autoit
   #AutoIt3Wrapper_Res_Description=Disk Health Viewer
   #AutoIt3Wrapper_Res_Fileversion=1.2.1.0
   #AutoIt3Wrapper_Res_ProductVersion=1.2.1.0
   #AutoIt3Wrapper_Res_Field=CompanyName|GexSoft
   ```
4. Compile (SciTE → **Tools → Compile** or press **F7**)

Output:
- `DiskHealthViewer.exe`

### 2) Python helper (smartread.py)

The GUI calls the helper like this:
- `smartread.exe --device "<DeviceID>" --smartctl "<path to smartctl.exe>"`
or
- `python smartread.py --device "<DeviceID>" --smartctl "<path to smartctl.exe>"`

So the helper must output the expected sections:
- `OVERVIEW`
- `SUMMARY`
- `ITEMS`

### 3) Optional: build smartread.exe (recommended for portability)

Why: users won’t need Python installed.

Common approach:
- Use **PyInstaller** on a dev machine:
  ```
  pyinstaller --onefile smartread.py --name smartread
  ```
- Put the result as:
  - `tools\smartread.exe`

(Exact build flags may vary depending on your Python environment.)

---

## Credits

- `smartctl` is part of **smartmontools**
- This GUI is a lightweight wrapper around smartctl output for practical tech use

---

