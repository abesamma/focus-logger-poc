# Focus Logger PoC

This Windows-only proof of concept logs foreground app changes to `focus-log.jsonl`.

## Run

```powershell
.\start.cmd
```

Optional arguments:

```powershell
.\start.cmd -PollIntervalMs 250
.\start.cmd -DurationSeconds 10
.\start.cmd -LogPath .\logs\focus-log.jsonl
```

Each line in the log is a JSON object with:

- `TimestampUtc`
- `ProcessId`
- `ProcessName`
- `WindowTitle`
- `Executable`
