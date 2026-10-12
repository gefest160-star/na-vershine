# Быстрая проверка проекта: запускает Godot без окна и печатает только ошибки скриптов.
param([string[]]$GameArgs = @(), [int]$Tail = 0, [switch]$Window, [string]$Res = "1600x900")
$ErrorActionPreference = "Continue"
$godot = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe" -Filter "*console.exe").FullName
$proj = Split-Path -Parent $PSScriptRoot
$a = @("--path", $proj)
if (-not $Window) { $a = @("--headless") + $a } else { $a = @("--windowed", "--resolution", $Res) + $a }
if ($GameArgs.Count -gt 0) { $a += "--"; $a += $GameArgs } else { $a += "--quit" }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $godot
$psi.Arguments = ($a | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join " "
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)
$errTask = $p.StandardError.ReadToEndAsync()
$out = $p.StandardOutput.ReadToEnd()
$p.WaitForExit()
$all = ($out + "`n" + $errTask.Result) -split "`r?`n"
$bad = @()
for ($i = 0; $i -lt $all.Count; $i++) {
    $l = $all[$i]
    if ($l -match "ERROR|WARNING") {
        if ($l -match "depended scripts") { continue }
        $loc = ""
        if ($i + 1 -lt $all.Count -and $all[$i + 1] -match "^\s+at:") { $loc = $all[$i + 1].Trim() }
        $bad += ($l.Trim() + "   " + $loc)
    }
}
if ($Tail -gt 0) { $all | Where-Object { $_ -notmatch "^\s*$" } | Select-Object -Last $Tail }
"---- problems: $($bad.Count)"
$bad | Select-Object -Unique | Select-Object -First 40
