param(
	[string]$GodotPath = "godot",
	[switch]$SkipPull,
	[switch]$SkipRun
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

function Invoke-CheckedCommand {
	param(
		[string]$Command,
		[string[]]$CommandArgs,
		[switch]$Quiet
	)

	if ($Quiet) {
		& $Command @CommandArgs | Out-Null
	} else {
		& $Command @CommandArgs
	}
	if ($LASTEXITCODE -ne 0) {
		throw "$Command $($CommandArgs -join ' ') failed with exit code $LASTEXITCODE"
	}
}

Invoke-CheckedCommand -Command "git" -CommandArgs @("rev-parse", "--is-inside-work-tree") -Quiet

if (-not $SkipPull) {
	$remote = (& git remote | Select-Object -First 1)
	if ([string]::IsNullOrWhiteSpace($remote)) {
		Write-Host "No git remote configured. Skipping pull."
	} else {
		Write-Host "Pulling latest code from $remote..."
		Invoke-CheckedCommand -Command "git" -CommandArgs @("pull", "--ff-only")
	}
}

if ($SkipRun) {
	Write-Host "Update finished. Skipping Godot launch."
	exit 0
}

Write-Host "Starting Godot project at $repoRoot..."
Invoke-CheckedCommand -Command $GodotPath -CommandArgs @("--path", $repoRoot.Path)
