[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\godot-proj\Godot_v4.6.3-stable_win64.exe',
    [string]$ProjectRoot,
    [switch]$SkipBoot
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
$GodotPath = [System.IO.Path]::GetFullPath($GodotPath)
$failures = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()

function Add-GateResult {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $script:results.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
    if (-not $Passed) { $script:failures.Add("${Name}: ${Detail}") }
}

function Invoke-CapturedProcess {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds = 180)
    $process = [System.Diagnostics.Process]::new()
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $ProjectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    if ($null -ne $startInfo.PSObject.Properties['StandardOutputEncoding']) {
        $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    }
    if ($null -ne $startInfo.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    } else {
        $escaped = foreach ($argument in $Arguments) {
            if ($argument -notmatch '[\s"]') { $argument; continue }
            '"' + ($argument -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        }
        $startInfo.Arguments = $escaped -join ' '
    }
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { return [pscustomobject]@{ ExitCode = -1; Output = 'process failed to start'; TimedOut = $false } }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            try { $process.WaitForExit() } catch { }
            return [pscustomobject]@{ ExitCode = -1; Output = ''; TimedOut = $true }
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = ($stdoutTask.Result + $stderrTask.Result); TimedOut = $false }
    } finally { $process.Dispose() }
}

function Test-AnchoredDiagnostics {
    param([string]$Text)
    return [regex]::IsMatch($Text, '(?m)^\s*(?:SCRIPT ERROR:|ERROR:|WARNING:\s+.*(?:orphan|leak)|Orphan (?:StringName|Node|Object):|ObjectDB instances leaked at exit|Resources still in use at exit)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Test-TextEncoding {
    $excluded = '[\\/](?:\.git|\.godot|build|export|cache)[\\/]'
    $extensions = @('.gd', '.tscn', '.tres', '.json', '.md', '.csv', '.ps1')
    $decoder = [System.Text.UTF8Encoding]::new($false, $true)
    $bad = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File) {
        if ($file.FullName -match $excluded -or $extensions -notcontains $file.Extension.ToLowerInvariant()) { continue }
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            if ($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))) { throw 'UTF-16 BOM' }
            if ($bytes -contains 0) { throw 'NUL byte' }
            [void]$decoder.GetString($bytes)
        } catch { $bad.Add("$($file.FullName): $($_.Exception.Message)") }
    }
    return $bad
}

function Read-Rfc4180Csv {
    param([string]$Path)
    Add-Type -AssemblyName Microsoft.VisualBasic
    $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($Path, [System.Text.Encoding]::UTF8, $true)
    try {
        $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
        $parser.SetDelimiters(',')
        $parser.HasFieldsEnclosedInQuotes = $true
        $rows = [System.Collections.Generic.List[object]]::new()
        while (-not $parser.EndOfData) { $rows.Add($parser.ReadFields()) }
        return $rows
    } finally { $parser.Dispose() }
}

function Test-AssetRegistry {
    param([string]$Path)
    $issues = [System.Collections.Generic.List[string]]::new()
    try { $rows = @(Read-Rfc4180Csv -Path $Path) } catch { $issues.Add("CSV parse failed: $($_.Exception.Message)"); return $issues }
    $expected = 'asset_id,source_type,source_uri,license,original_changes,project_path,review_status'
    if ($rows.Count -eq 0 -or (($rows[0] -join ',') -cne $expected)) { $issues.Add("header must be exactly $expected"); return $issues }
    $ids = @{}; $paths = @{}
    $sourceTypes = @('original', 'rightcode_draw_original', 'open_source', 'commercial')
    $statuses = @('planned', 'generated', 'reviewed', 'approved', 'rejected')
    for ($i = 1; $i -lt $rows.Count; $i++) {
        $row = $rows[$i]
        if ($row.Count -ne 7) { $issues.Add("row $($i + 1) has $($row.Count) fields"); continue }
        $id, $type, $uri, $license, $changes, $projectPath, $status = $row
        if ([string]::IsNullOrWhiteSpace($id)) { $issues.Add("row $($i + 1) has empty asset_id") }
        elseif ($ids.ContainsKey($id)) { $issues.Add("duplicate asset_id: $id") } else { $ids[$id] = $true }
        if ($sourceTypes -notcontains $type) { $issues.Add("$id has invalid source_type: $type") }
        if ($statuses -notcontains $status) { $issues.Add("$id has invalid review_status: $status") }
        if ([string]::IsNullOrWhiteSpace($license)) { $issues.Add("$id has empty license") }
        if ($type -in @('original', 'rightcode_draw_original') -and $license -notmatch '(?i)original') { $issues.Add("$id original license must identify Original provenance") }
        if ($type -ne 'original' -and [string]::IsNullOrWhiteSpace($license)) { $issues.Add("$id non-original license must not be empty") }
        if ($uri -match '(?i)(?:password|token|secret|api[_-]?key)\s*[:=]|(?:^[A-Za-z]:\\)|(?:^\\\\)|(?:^/tmp/)|(?:^file:)|(?:[\\/]AppData[\\/])|%TEMP%') { $issues.Add("$id source_uri contains a secret or local temporary path") }
        if ([string]::IsNullOrWhiteSpace($projectPath)) { $issues.Add("$id has empty project_path") }
        elseif ($paths.ContainsKey($projectPath)) { $issues.Add("duplicate project_path: $projectPath") } else { $paths[$projectPath] = $true }
        if ($projectPath -match '(^|[\\/])\.\.([\\/]|$)' -or $projectPath -match '^[A-Za-z]:[\\/]' -or $projectPath.StartsWith('/') -or $projectPath.StartsWith('\\')) { $issues.Add("$id project_path is absolute or traverses: $projectPath") }
        elseif ($projectPath -notmatch '^(?:res://|docs/|tools/)') { $issues.Add("$id project_path must use res://, docs/, or tools/") }
        if ($status -in @('reviewed', 'approved')) {
            $diskPath = if ($projectPath.StartsWith('res://')) { Join-Path $ProjectRoot $projectPath.Substring(6) } else { Join-Path $ProjectRoot $projectPath }
            if (-not (Test-Path -LiteralPath $diskPath)) { $issues.Add("$id $status project_path does not exist: $projectPath") }
        }
    }
    return $issues
}

$requiredFiles = @(
    'project.godot',
    'docs/phase-gates/chapter-one-greybox.md',
    'docs/asset-registry.csv',
    'docs/imagegen/prompt-registry.md',
    'tools/validate_project.ps1'
)
$missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_)) })
Add-GateResult 'Required files' ($missing.Count -eq 0) $(if ($missing.Count) { 'missing: ' + ($missing -join ', ') } else { 'all present' })
Add-GateResult 'Godot executable' (Test-Path -LiteralPath $GodotPath -PathType Leaf) $GodotPath

$encodingIssues = @(Test-TextEncoding)
Add-GateResult 'UTF-8 text scan' ($encodingIssues.Count -eq 0) $(if ($encodingIssues.Count) { $encodingIssues -join '; ' } else { 'valid UTF-8; no UTF-16 BOM or NUL' })

$jsonIssues = [System.Collections.Generic.List[string]]::new()
foreach ($json in Get-ChildItem -LiteralPath $ProjectRoot -Recurse -Filter '*.json' -File | Where-Object { $_.FullName -notmatch '[\\/](?:\.git|\.godot|build|export|cache)[\\/]' }) {
    try { [void](Get-Content -Raw -Encoding UTF8 -LiteralPath $json.FullName | ConvertFrom-Json) } catch { $jsonIssues.Add("$($json.FullName): $($_.Exception.Message)") }
}
Add-GateResult 'JSON parse' ($jsonIssues.Count -eq 0) $(if ($jsonIssues.Count) { $jsonIssues -join '; ' } else { 'all JSON parsed' })

$assetPath = Join-Path $ProjectRoot 'docs/asset-registry.csv'
if (Test-Path -LiteralPath $assetPath) {
    $assetIssues = @(Test-AssetRegistry -Path $assetPath)
    Add-GateResult 'Asset registry' ($assetIssues.Count -eq 0) $(if ($assetIssues.Count) { $assetIssues -join '; ' } else { 'schema, provenance, enums, uniqueness, and paths valid' })
} else { Add-GateResult 'Asset registry' $false 'file missing' }

$promptPath = Join-Path $ProjectRoot 'docs/imagegen/prompt-registry.md'
if (Test-Path -LiteralPath $promptPath) {
    $prompt = Get-Content -Raw -Encoding UTF8 -LiteralPath $promptPath
    $promptPatterns = @('Asset ID', 'myimage-gen use-case slug', 'Right Code Draw', 'gpt-image-2', '1024x768', 'medium', '300', 'D:\\CODEX-PROJ\\draw.txt', 'concept_manifest_raw.json', 'concept_manifest_verified.json', 'concept_contact_sheet.png', 'prompts.md', 'Final prompt', 'Generated file', 'Selected version', 'Intended 3D/UI use', 'Reviewer', 'License/source notes', 'hero', 'boss', 'environment', 'UI', 'VFX', 'Boss mesh budget equals hero')
    $promptMissing = @($promptPatterns | Where-Object { $prompt -notmatch $_ })
    Add-GateResult 'Prompt registry' ($promptMissing.Count -eq 0 -and $prompt -notmatch '\$imagegen') $(if ($promptMissing.Count -or $prompt -match '\$imagegen') { 'missing fields/topics or legacy policy detected: ' + (($promptMissing + @('legacy $imagegen policy')) -join ', ') } else { 'Right Code Draw/myimage-gen templates, batch manifests, categories, and policy present' })
} else { Add-GateResult 'Prompt registry' $false 'file missing' }

$gatePath = Join-Path $ProjectRoot 'docs/phase-gates/chapter-one-greybox.md'
if (Test-Path -LiteralPath $gatePath) {
    $gate = Get-Content -Raw -Encoding UTF8 -LiteralPath $gatePath
    $gatePatterns = @('full playthrough', 'invalid command handling', 'deterministic digest', 'save restore', 'keyboard flow', 'viewport framing', 'clean engine logs', 'PASS', 'Command', 'Time', 'Commit SHA', 'Godot version', 'Evidence file', 'Limitations', 'Phase 1 greybox gate')
    $gateMissing = @($gatePatterns | Where-Object { $gate -notmatch $_ })
    $evidenceLinks = [regex]::Matches($gate, 'tests/evidence/[A-Za-z0-9._-]+\.txt') | ForEach-Object Value | Select-Object -Unique
    $missingEvidence = @($evidenceLinks | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_)) })
    Add-GateResult 'Phase gate record' ($gateMissing.Count -eq 0 -and $evidenceLinks.Count -ge 3 -and $missingEvidence.Count -eq 0) $(if ($gateMissing.Count -or $missingEvidence.Count -or $evidenceLinks.Count -lt 3) { "missing fields=$($gateMissing -join ','); evidence links=$($evidenceLinks.Count); missing evidence=$($missingEvidence -join ',')" } else { 'PASS claims include metadata and existing evidence links' })
} else { Add-GateResult 'Phase gate record' $false 'file missing' }

$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $git) {
    $diff = Invoke-CapturedProcess -FilePath $git.Source -Arguments @('-C', $ProjectRoot, 'diff', '--check') -TimeoutSeconds 30
    Add-GateResult 'git diff --check' ($diff.ExitCode -eq 0) $(if ($diff.ExitCode -eq 0) { 'no whitespace errors' } else { $diff.Output.Trim() })
} else { Add-GateResult 'git diff --check' $false 'git executable not found' }

if ((Test-Path -LiteralPath $GodotPath) -and (Test-Path -LiteralPath (Join-Path $ProjectRoot 'project.godot'))) {
    $full = Invoke-CapturedProcess -FilePath $GodotPath -Arguments @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/run_all.gd', '--quit-after', '120') -TimeoutSeconds 300
    $fullPass = -not $full.TimedOut -and $full.ExitCode -eq 0 -and $full.Output -match 'Ran 12 test file\(s\): 12 passed, 0 failed\.' -and -not (Test-AnchoredDiagnostics $full.Output)
    Add-GateResult 'Full test suite 12/12' $fullPass $(if ($fullPass) { 'Ran 12 test file(s): 12 passed, 0 failed.' } elseif ($full.TimedOut) { 'timed out' } else { "exit=$($full.ExitCode); expected explicit 12/12; output=$($full.Output.Trim())" })

    $keyWorkers = @(
        'test_chapter_one_playthrough.gd',
        'test_save_service.gd',
        'test_e2e_scene_flow.gd'
    )
    foreach ($workerName in $keyWorkers) {
        $workerPath = "res://tests/$workerName"
        $worker = Invoke-CapturedProcess -FilePath $GodotPath -Arguments @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/run_all.gd', '--quit-after', '120', '--', '--test-runner-worker', $workerPath) -TimeoutSeconds 180
        $workerPass = -not $worker.TimedOut -and $worker.ExitCode -eq 0 -and $worker.Output -match ("(?m)^PASS {0}\s*$" -f [regex]::Escape($workerName)) -and -not (Test-AnchoredDiagnostics $worker.Output)
        Add-GateResult "Fresh worker $workerName" $workerPass $(if ($workerPass) { "PASS $workerName" } elseif ($worker.TimedOut) { 'timed out' } else { "exit=$($worker.ExitCode); output=$($worker.Output.Trim())" })
    }

    $resource = Invoke-CapturedProcess -FilePath $GodotPath -Arguments @('--headless', '--path', $ProjectRoot, '--quit-after', '1') -TimeoutSeconds 120
    $resourcePass = -not $resource.TimedOut -and $resource.ExitCode -eq 0 -and -not (Test-AnchoredDiagnostics $resource.Output)
    Add-GateResult 'Godot parser/resource smoke' $resourcePass $(if ($resourcePass) { 'headless main-scene parse/resource load completed cleanly' } else { "exit=$($resource.ExitCode); output=$($resource.Output.Trim())" })

    if ($SkipBoot) {
        Add-GateResult 'Boot smoke 120 frames' $true 'SKIPPED by explicit test-only -SkipBoot injection'
    } else {
        $boot = Invoke-CapturedProcess -FilePath $GodotPath -Arguments @('--headless', '--path', $ProjectRoot, '--quit-after', '120') -TimeoutSeconds 180
        $bootPass = -not $boot.TimedOut -and $boot.ExitCode -eq 0 -and -not (Test-AnchoredDiagnostics $boot.Output)
        Add-GateResult 'Boot smoke 120 frames' $bootPass $(if ($bootPass) { '120-frame boot completed without anchored diagnostics' } elseif ($boot.TimedOut) { 'timed out' } else { "exit=$($boot.ExitCode); output=$($boot.Output.Trim())" })
    }
} else {
    Add-GateResult 'Full test suite 12/12' $false 'Godot executable or project.godot missing'
    Add-GateResult 'Fresh worker test_chapter_one_playthrough.gd' $false 'Godot executable or project.godot missing'
    Add-GateResult 'Fresh worker test_save_service.gd' $false 'Godot executable or project.godot missing'
    Add-GateResult 'Fresh worker test_e2e_scene_flow.gd' $false 'Godot executable or project.godot missing'
    Add-GateResult 'Godot parser/resource smoke' $false 'Godot executable or project.godot missing'
    Add-GateResult 'Boot smoke 120 frames' $false 'Godot executable or project.godot missing'
}

Write-Output ''
Write-Output '=== Project validation summary ==='
foreach ($result in $results) {
    Write-Output ('[{0}] {1} - {2}' -f $(if ($result.Passed) { 'PASS' } else { 'FAIL' }), $result.Name, $result.Detail)
}
Write-Output ('TOTAL: {0} passed, {1} failed' -f @($results | Where-Object Passed).Count, @($results | Where-Object { -not $_.Passed }).Count)
if ($failures.Count -gt 0) { exit 1 }
exit 0
