param(
    [string]$LogPath = (Join-Path $PSScriptRoot "focus-log.jsonl"),
    [int]$PollIntervalMs = 500,
    [int]$DurationSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ForegroundWindow
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

function Get-FocusedAppSnapshot {
    $handle = [ForegroundWindow]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) {
        return $null
    }

    $length = [ForegroundWindow]::GetWindowTextLength($handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 1))
    [void][ForegroundWindow]::GetWindowText($handle, $builder, $builder.Capacity)

    [uint32]$processId = 0
    [void][ForegroundWindow]::GetWindowThreadProcessId($handle, [ref]$processId)
    if ($processId -eq 0) {
        return $null
    }

    $process = Get-Process -Id $processId
    $path = $null
    try {
        $path = $process.Path
    }
    catch {
        $path = $null
    }

    [pscustomobject]@{
        TimestampUtc = [DateTime]::UtcNow.ToString("o")
        ProcessId    = [int]$processId
        ProcessName  = $process.ProcessName
        WindowTitle  = $builder.ToString()
        Executable   = $path
    }
}

$logDirectory = Split-Path -Parent $LogPath
if ($logDirectory -and -not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

$stopAt = if ($DurationSeconds -gt 0) { (Get-Date).AddSeconds($DurationSeconds) } else { $null }
$lastSignature = $null

Write-Host "Logging focused app changes to $LogPath"
Write-Host "Press Ctrl+C to stop."

while ($true) {
    if ($stopAt -and (Get-Date) -ge $stopAt) {
        break
    }

    $snapshot = Get-FocusedAppSnapshot
    if ($null -ne $snapshot) {
        $signature = "{0}|{1}|{2}" -f $snapshot.ProcessId, $snapshot.ProcessName, $snapshot.WindowTitle
        if ($signature -ne $lastSignature) {
            $snapshot | ConvertTo-Json -Compress | Add-Content -Path $LogPath
            Write-Host ("[{0}] {1} - {2}" -f $snapshot.TimestampUtc, $snapshot.ProcessName, $snapshot.WindowTitle)
            $lastSignature = $signature
        }
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}
