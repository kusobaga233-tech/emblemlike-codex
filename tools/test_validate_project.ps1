[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\godot-proj\Godot_v4.6.3-stable_win64.exe'
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validatorName = 'tools/validate_project.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("star-ember-validator-tests-{0}" -f [guid]::NewGuid())
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function New-CaseProject {
    param([string]$Name)
    $destination = Join-Path $tempRoot $Name
    [void](New-Item -ItemType Directory -Path $destination -Force)
    foreach ($entry in Get-ChildItem -LiteralPath $sourceRoot -Force | Where-Object { $_.Name -notin @('.git', '.godot') }) {
        Copy-Item -LiteralPath $entry.FullName -Destination $destination -Recurse -Force
    }
    return $destination
}

function Invoke-ValidatorCase {
    param([string]$Name, [scriptblock]$Mutate, [string]$ExpectedPattern, [string]$OverrideGodotPath = $GodotPath)
    $caseRoot = New-CaseProject -Name $Name
    & $Mutate $caseRoot
    $output = & (Join-Path $caseRoot $validatorName) -ProjectRoot $caseRoot -GodotPath $OverrideGodotPath -SkipBoot 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0 -or $output -notmatch $ExpectedPattern) {
        $script:failures.Add("$Name expected nonzero and /$ExpectedPattern/; exit=$exitCode; output=$output")
        Write-Output "FAIL $Name"
    } else {
        $script:passed++
        Write-Output "PASS $Name"
    }
}

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    Invoke-ValidatorCase 'missing-file' { param($root) Remove-Item -LiteralPath (Join-Path $root 'docs/imagegen/prompt-registry.md') -Force } 'Prompt registry|Required files'

    Invoke-ValidatorCase 'legacy-imagegen-policy' {
        param($root)
        $path = Join-Path $root 'docs/imagegen/prompt-registry.md'
        $text = "# Legacy registry`n`nThis file intentionally omits the Right Code Draw contract.`n"
        Write-Utf8NoBom $path $text
    } 'Prompt registry'

    Invoke-ValidatorCase 'bad-utf8' {
        param($root)
        [System.IO.File]::WriteAllBytes((Join-Path $root 'docs/bad-utf8.md'), [byte[]](0xC3, 0x28))
    } 'UTF-8 text scan'

    Invoke-ValidatorCase 'empty-license' {
        param($root)
        $path = Join-Path $root 'docs/asset-registry.csv'
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $text = $text -replace 'Original generated through Right Code Draw; batch manifest and visual inspection recorded,"Reference generated; not yet selected or copied into the Godot project",res://assets/production/concepts/heroes/hero-ember-warden.png', ',"Reference generated; not yet selected or copied into the Godot project",res://assets/production/concepts/heroes/hero-ember-warden.png'
        Write-Utf8NoBom $path $text
    } 'empty license'

    Invoke-ValidatorCase 'duplicate-id-path' {
        param($root)
        $path = Join-Path $root 'docs/asset-registry.csv'
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $text += "`ngreybox-board-runtime,original,,Original project-authored procedural primitives,Duplicate,res://src/presentation/greybox_board.gd,reviewed`n"
        Write-Utf8NoBom $path $text
    } 'duplicate asset_id|duplicate project_path'

    Invoke-ValidatorCase 'traversal' {
        param($root)
        $path = Join-Path $root 'docs/asset-registry.csv'
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).Replace('res://assets/production/concepts/weapons/weapon-family.png', 'res://../outside.png')
        Write-Utf8NoBom $path $text
    } 'absolute or traverses'

    Invoke-ValidatorCase 'approved-missing-path' {
        param($root)
        $path = Join-Path $root 'docs/asset-registry.csv'
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).Replace('res://assets/production/concepts/vfx/chapter-one-styleboard.png,planned', 'res://assets/production/concepts/vfx/missing-approved.png,approved')
        Write-Utf8NoBom $path $text
    } 'approved project_path does not exist'

    Invoke-ValidatorCase 'fake-pass-test-failure' {
        param($root)
        $runner = @'
extends SceneTree
func _init() -> void:
	print("Ran 12 test file(s): 12 passed, 0 failed.")
	quit(1)
'@
        Write-Utf8NoBom (Join-Path $root 'tests/run_all.gd') $runner
    } 'Full test suite 13/13'

    Invoke-ValidatorCase 'missing-godot-command' { param($root) } 'Godot executable|Godot executable or project.godot missing' (Join-Path $tempRoot 'does-not-exist.exe')
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Output ("Validator negative tests: {0} passed, {1} failed" -f $passed, $failures.Count)
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output $_ }
    exit 1
}
exit 0
