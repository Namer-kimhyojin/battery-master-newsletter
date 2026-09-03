param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFile,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$IssueDate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = $PSScriptRoot
$archiveDirectory = Join-Path $repositoryRoot 'archive'
$archiveFile = Join-Path $archiveDirectory "$IssueDate.html"
$latestFile = Join-Path $repositoryRoot 'index.html'
$resolvedSource = (Resolve-Path -LiteralPath $SourceFile).Path

New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
Copy-Item -LiteralPath $resolvedSource -Destination $archiveFile -Force
Copy-Item -LiteralPath $resolvedSource -Destination $latestFile -Force

Push-Location $repositoryRoot
try {
    git add -- 'index.html' "archive/$IssueDate.html"
    $pendingChanges = git status --porcelain -- 'index.html' "archive/$IssueDate.html"
    if (-not $pendingChanges) {
        Write-Output "No newsletter changes to publish for $IssueDate."
        exit 0
    }

    git commit -m "Publish battery newsletter $IssueDate"
    git push origin main
    Write-Output "Published battery newsletter $IssueDate."
}
finally {
    Pop-Location
}
