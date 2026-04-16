
# ScreenshotOrganizer

Scans a folder of screenshots and moves them into a date-based hierarchy,
renaming each file to a Windows-safe ISO 8601 timestamp.

**Before:**
```
Screenshots\
  Screenshot 2026-04-16 133742.png
  Screenshot 2026-04-15 091023.png
```

**After:**
```
Screenshots\
  2026\
    04 - April\
      2026-04-16\
        2026-04-16T13-37-42.png
      2026-04-15\
        2026-04-15T09-10-23.png
```

---

## Timestamp Selection

PowerShell has no built-in EXIF reader. Windows screenshots (Win+PrtScn,
Snipping Tool, Snip & Sketch, Xbox Game Bar) do not embed EXIF
DateTimeOriginal -- they are screen captures, not camera photos. The tool
therefore relies on filesystem timestamps in this order:

1. **CreationTime** -- The NTFS timestamp set when the OS first writes the
   file. For Windows screenshots this equals the moment of capture.
2. **LastWriteTime** -- Fallback for files whose CreationTime was reset by
   OneDrive sync, robocopy, or a backup restore that did not preserve creation
   timestamps.
3. **Current time** -- Last resort if both timestamps are invalid (pre-1970).
   A warning is logged and the current time is used.

If you add an EXIF/metadata reader later, insert its call inside
`modules\Timestamp.psm1` before the `CreationTime` check.

---

## Project Structure

```
ScreenshotOrganizer\
  ScreenshotOrganizer.ps1    Entry point; all CLI parameters
  modules\
    Config.psm1              Load config, apply CLI overrides
    Logging.psm1             Structured logger (console + log file)
    Timestamp.psm1           Timestamp selection logic
    PathGen.psm1             Folder/filename generation and collision handling
    FileOps.psm1             File move + undo entry writing
    UndoOps.psm1             Reverse the last run
    Summary.psm1             Final stats table
  config\
    settings.json            User-editable defaults
  logs\                      One .log file created per run
  undo\                      One .json file created per run + latest.txt
  tests\
    Run-Tests.ps1            Unit tests
  README.md
```

---

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Your execution policy must allow local scripts. Run once as Administrator:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## Configuration

Edit `config\settings.json` to change defaults:

```json
{
    "SourceFolder":        "C:\\Users\\Isaiah\\OneDrive\\Pictures\\Screenshots",
    "DestinationRoot":     "C:\\Users\\Isaiah\\OneDrive\\Pictures\\Screenshots",
    "SupportedExtensions": [".png", ".jpg", ".jpeg", ".webp"],
    "LogFolder":           "C:\\Projects\\ScreenshotOrganizer\\logs",
    "UndoFolder":          "C:\\Projects\\ScreenshotOrganizer\\undo"
}
```

| Key                  | Description                                                  |
|----------------------|--------------------------------------------------------------|
| `SourceFolder`       | Folder to scan for screenshots                               |
| `DestinationRoot`    | Root under which the YYYY\MM\DD hierarchy is created         |
| `SupportedExtensions`| List of file extensions to process (lowercase, with dot)     |
| `LogFolder`          | Where to write run logs                                      |
| `UndoFolder`         | Where to write undo logs                                     |

`SourceFolder` and `DestinationRoot` can point to the same folder. Files
already in the correct structure are automatically detected and skipped.

---

## Usage

Open PowerShell and `cd` to the project folder, or use the full path.

### Normal run

```powershell
cd C:\Projects\ScreenshotOrganizer
.\ScreenshotOrganizer.ps1
```

### Dry run (no files moved)

```powershell
.\ScreenshotOrganizer.ps1 -DryRun
```

### Dry run with verbose skip messages

```powershell
.\ScreenshotOrganizer.ps1 -DryRun -Verbose
```

### Undo the last run

```powershell
.\ScreenshotOrganizer.ps1 -UndoLast
```

### Preview the undo without reversing it

```powershell
.\ScreenshotOrganizer.ps1 -UndoLast -DryRun
```

### Override the source or destination for this run only

```powershell
.\ScreenshotOrganizer.ps1 -SourcePath "D:\Captures" -DestinationRoot "D:\Organized"
```

### Use a different config file

```powershell
.\ScreenshotOrganizer.ps1 -ConfigPath "C:\MyConfigs\alt-settings.json"
```

---

## Running from anywhere

To run without `cd`-ing first:

```powershell
& "C:\Projects\ScreenshotOrganizer\ScreenshotOrganizer.ps1" -DryRun
```

---

## Logs

Each run writes a log to `logs\run_YYYY-MM-DDTHH-mm-ss.log`. Format:

```
[2026-04-16T13:42:08] [INFO] ScreenshotOrganizer started
[2026-04-16T13:42:08] [INFO] Source      : C:\Users\Isaiah\OneDrive\Pictures\Screenshots
[2026-04-16T13:42:08] [INFO] Moved : C:\...\Screenshot 2026-04-16.png
[2026-04-16T13:42:08] [INFO]     -> C:\...\2026\04 - April\2026-04-16\2026-04-16T13-42-08.png
[2026-04-16T13:42:08] [SKIP] Already processed: ...
[2026-04-16T13:42:08] [ERROR] Failed '...': Access is denied.
```

Levels: `INFO`, `SKIP`, `WARN`, `ERROR`, `DRY` (dry-run actions).

---

## Undo

Each run that moves at least one file writes an undo file to
`undo\undo_YYYY-MM-DDTHH-mm-ss.json`. Each line is a JSON object:

```json
{"From":"C:\\...\\2026-04-16T13-42-08.png","To":"C:\\...\\Screenshot 2026-04-16.png"}
```

`undo\latest.txt` contains the path to the most recent undo file.
`-UndoLast` reads `latest.txt`, reads the undo file, and reverses every
move. On full success it clears `latest.txt` so a second `-UndoLast` is
a no-op until you run the organizer again.

---

## Running the Tests

```powershell
.\tests\Run-Tests.ps1
```

A passing run exits with code 0. A failing run exits with code 1 and
prints which assertions failed.

---

## Assumptions

1. Month names in folder paths use the system locale. On an English Windows
   installation this produces "April", "January", etc. If you change locale,
   existing folders will not be renamed automatically.
2. `SourceFolder` is scanned recursively, so organized subfolders are
   included in the scan. The `Test-AlreadyProcessed` function skips any
   file that already lives in the correct YYYY\MM - MonthName\YYYY-MM-DD
   structure with a correctly-named timestamp filename.
3. The tool does not delete empty folders left behind after moves. You can
   clean these manually or add a post-run sweep if needed.
4. Undo only covers the most recent run. Older undo files remain in the
   `undo\` folder and can be replayed manually if needed.

---

## Future Improvements

1. **EXIF support via ExifTool.** Wrap the free standalone `exiftool.exe`
   binary (placed in `tools\`) to read `DateTimeOriginal` for JPEGs and
   PNG creation metadata. Insert the call in `Timestamp.psm1` before the
   `CreationTime` check. This would improve accuracy for screenshots
   imported from phones or cameras.

2. **Multi-run undo stack.** Replace the single `latest.txt` pointer with
   a stack (e.g. `undo-stack.json` listing undo files in order). Add a
   `-UndoSteps N` parameter to reverse multiple runs in sequence. Useful
   when you run the organizer several times and want to roll back several
   sessions.

3. **Scheduled / watch mode.** Add a `-Watch` switch that uses a
   `FileSystemWatcher` to process new screenshots as they arrive, rather
   than requiring a manual run. Pair with a Task Scheduler entry created
   by an `Install-ScheduledTask.ps1` helper script for a fully automated
   pipeline.
