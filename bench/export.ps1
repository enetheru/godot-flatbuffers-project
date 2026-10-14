# Export preset "bench" to bench/out/bench.pck.
# Same routine as run.ps1, without a suite run.
# .\export.ps1
# Launch the editor exe. The .console.exe wrapper is a second process.

$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$editor = "C:\build\godot\w64.mingw64.x86_64.windows.editor.default.4.7\bin\godot.windows.editor.x86_64.exe"
$script:benchExit = 0
$benchTimeoutSec = 600

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
}

Export-BenchPack
exit $script:benchExit
