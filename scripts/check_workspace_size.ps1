param(
    [double]$MaxSizeGB = 5,
    [int]$Top = 20
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$files = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force |
    Where-Object { $_.FullName -notlike "$repoRoot\.git\*" }

$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
if ($null -eq $totalBytes) { $totalBytes = 0 }
$totalGB = $totalBytes / 1GB

Write-Output ("Workspace: {0}" -f $repoRoot)
Write-Output ("Size excluding .git: {0:N3} GiB (limit {1:N3} GiB)" -f $totalGB, $MaxSizeGB)
Write-Output 'Largest files:'
$files |
    Sort-Object Length -Descending |
    Select-Object -First $Top @{Name='MiB';Expression={[math]::Round($_.Length / 1MB, 2)}}, FullName |
    Format-Table -AutoSize

if ($totalGB -gt $MaxSizeGB) {
    Write-Error ("Workspace size exceeds the configured {0:N3} GiB limit." -f $MaxSizeGB)
    exit 1
}
