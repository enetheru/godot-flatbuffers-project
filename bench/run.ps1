# Run res://bench/run.gd.
# The editor binary can open this project with --path.
# The template binaries were built without path overrides, and they also drop
# --script. The pack is named after the exe. BenchScene reads the token after
# -- and quits when the suite finishes.
# Launch the real exe, not the .console.exe wrapper. The wrapper is a second
# process that waits until every child Godot spawned has exited, so the
# console stays open after Godot itself has quit.
# The extension DLL stays out of the pack. Godot loads a packed library with
# LoadLibrary on a path that is not a real file (error 126). If the DLL is
# absent from the pack, Godot loads the matching filename from beside the exe.
# Rows append to bench/results/history.tres (a BenchHistory resource).
# One timestamp covers every row from that process. Absent measurements are nan.
# .\run.ps1
# .\run.ps1 -Target template_release
# .\run.ps1 -Target editor -Suite prealloc
param(
	[ValidateSet("all", "editor", "template_debug", "template_release")]
	[string]$Target = "all",
	[ValidateSet("suite", "all", "prealloc", "array-size")]
	[string]$Suite = "suite"
)

$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$editor = "C:\build\godot\w64.mingw64.x86_64.windows.editor.default.4.7\bin\godot.windows.editor.x86_64.exe"
$templates = [ordered]@{
	template_debug = "C:\build\godot\w64.mingw64.x86_64.windows.template_debug.default.4.7\bin\godot.windows.template_debug.x86_64.exe"
	template_release = "C:\build\godot\w64.mingw64.x86_64.windows.template_release.default.4.7\bin\godot.windows.template_release.x86_64.exe"
}
$script:benchExit = 0
$script:benchPack = $null
$script:history = ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "results\history.tres"))).Replace("\", "/")
$benchTimeoutSec = 600
New-Item -ItemType Directory -Force -Path (Split-Path $script:history) | Out-Null

function Invoke-Native([string]$Exe, [string[]]$ArgumentList, [int]$TimeoutSec) {
	$psi = [System.Diagnostics.ProcessStartInfo]::new()
	$psi.FileName = $Exe
	$psi.UseShellExecute = $false
	foreach ($arg in $ArgumentList) {
		[void]$psi.ArgumentList.Add($arg)
	}
	$proc = [System.Diagnostics.Process]::new()
	$proc.StartInfo = $psi
	[void]$proc.Start()
	if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
		& taskkill.exe /T /F /PID $proc.Id | Out-Null
		$script:benchExit = 124
		Write-Host "=== timed out after ${TimeoutSec}s ==="
		return
	}
	$script:benchExit = $proc.ExitCode
}

function Invoke-Bench([string]$Exe, [string]$Name) {
	Write-Host "=== $Name $Suite ==="
	Invoke-Native $Exe @(
		"--headless", "--path", $project, "--", $Suite, $Name, $script:history
	) $benchTimeoutSec
}

function Export-BenchPack {
	$out = Join-Path $PSScriptRoot "out"
	New-Item -ItemType Directory -Force -Path $out | Out-Null
	$pck = Join-Path $out "bench.pck"
	Write-Host "=== export bench.pck ==="
	Invoke-Native $editor @(
		"--headless", "--path", $project, "--export-pack", "bench", $pck
	) $benchTimeoutSec
	if ($script:benchExit -ne 0) {
		throw "export-pack failed: $script:benchExit"
	}
	$script:benchPack = $pck
}

function Invoke-Template([string]$Name, [string]$SourceExe, [string]$Pack) {
	$out = Join-Path $PSScriptRoot "out"
	$dllName = "flatbuffers.windows.$Name.x86_64.dll"
	$dllSrc = Join-Path $project "addons\enetheru.flatbuffers-extension\bin\$dllName"
	Copy-Item -LiteralPath $SourceExe -Destination (Join-Path $out "$Name.exe") -Force
	Copy-Item -LiteralPath $Pack -Destination (Join-Path $out "$Name.pck") -Force
	Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $out $dllName) -Force
	Write-Host "=== $Name $Suite ==="
	Invoke-Native (Join-Path $out "$Name.exe") @(
		"--headless", "--", $Suite, $Name, $script:history
	) $benchTimeoutSec
}

$names = @("editor", "template_debug", "template_release")
if ($Target -ne "all") {
	$names = @($Target)
}

$failed = 0
foreach ($name in $names) {
	$script:benchExit = 0
	if ($name -eq "editor") {
		Invoke-Bench $editor "editor"
	} else {
		if (-not $script:benchPack) {
			Export-BenchPack
		}
		Invoke-Template $name $templates[$name] $script:benchPack
	}
	if ($script:benchExit -ne 0) {
		Write-Host "=== $name exit $script:benchExit ==="
		$failed++
	}
}

exit $failed
