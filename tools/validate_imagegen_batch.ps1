param(
    [string]$BatchDirectory = "D:\CODEX-PROJ\common\outputs\imagegen\star-ember-oath-ch1-characters-v02"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$rawPath = Join-Path $BatchDirectory "concept_manifest_raw.json"
$verifiedPath = Join-Path $BatchDirectory "concept_manifest_verified.json"
$reviewPath = Join-Path $BatchDirectory "visual_review.md"

foreach ($path in @($rawPath, $verifiedPath, $reviewPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing batch evidence: $path"
    }
}

$raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $rawPath | ConvertFrom-Json
$verified = Get-Content -Raw -Encoding UTF8 -LiteralPath $verifiedPath | ConvertFrom-Json
if ($raw.Count -ne 6 -or $verified.Count -ne 6) {
    throw "Expected six raw and six verified entries."
}

$rawRequired = @(
    "model", "requested_size", "quality", "request_timeout", "output_root", "output_dir",
    "prompt", "image_path", "image_url", "response_json", "returncode", "stdout", "stderr",
    "final_path", "attempt_count", "attempts", "width", "height", "bytes", "sha256",
    "actual_aspect_ratio", "aspect_consistent_with_request"
)
$verifiedRequired = @(
    "model", "requested_size", "quality", "status", "returncode", "image_url", "attempt_count",
    "attempts", "raw_manifest", "raw_entry_index", "output_dir", "final_path", "bytes", "sha256",
    "width", "height", "actual_aspect_ratio", "aspect_consistent_with_request"
)

foreach ($entry in $raw) {
    foreach ($field in $rawRequired) {
        if ($null -eq $entry.PSObject.Properties[$field] -or $null -eq $entry.$field) {
            throw "Raw entry $($entry.index) missing $field"
        }
    }
}
foreach ($entry in $verified) {
    foreach ($field in $verifiedRequired) {
        if ($null -eq $entry.PSObject.Properties[$field] -or $null -eq $entry.$field) {
            throw "Verified entry $($entry.index) missing $field"
        }
    }
    $file = Get-Item -LiteralPath $entry.final_path
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    if ($file.Length -ne $entry.bytes -or $hash -ne $entry.sha256) {
        throw "Verified file evidence mismatch for entry $($entry.index)"
    }
    $bitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
    try {
        $measuredWidth = $bitmap.Width
        $measuredHeight = $bitmap.Height
    }
    finally {
        $bitmap.Dispose()
    }
    $measuredAspect = $measuredWidth / $measuredHeight
    if ($measuredWidth -ne $entry.width -or $measuredHeight -ne $entry.height) {
        throw "Measured dimensions mismatch for entry $($entry.index)"
    }
    if ([Math]::Abs($measuredAspect - $entry.actual_aspect_ratio) -gt 0.000001) {
        throw "Measured aspect mismatch for entry $($entry.index)"
    }
    if (-not $entry.aspect_consistent_with_request) {
        throw "Aspect verification failed for entry $($entry.index)"
    }
}

Write-Output "PASS: six complete raw and verified image-generation evidence entries."
