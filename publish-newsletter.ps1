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
    if ($pendingChanges) {
        git commit -m "Publish battery newsletter $IssueDate"
        git push origin main
    }
    else {
        Write-Output "No Git changes to publish for $IssueDate."
    }

    $deploymentDirectory = Join-Path $repositoryRoot '.pages-output'
    $deploymentArchive = Join-Path $deploymentDirectory 'archive'
    New-Item -ItemType Directory -Path $deploymentArchive -Force | Out-Null
    Copy-Item -LiteralPath $latestFile -Destination (Join-Path $deploymentDirectory 'index.html') -Force
    Copy-Item -Path (Join-Path $archiveDirectory '*') -Destination $deploymentArchive -Force

    $npxCommand = (Get-Command npx -ErrorAction Stop).Source
    $commitHash = git rev-parse HEAD
    & $npxCommand --yes wrangler@4.128.0 pages deploy $deploymentDirectory --project-name batterybrief --branch main --commit-hash $commitHash
    if ($LASTEXITCODE -ne 0) {
        throw 'Cloudflare Pages deployment failed.'
    }

    Write-Output "Published battery newsletter $IssueDate to GitHub and Cloudflare Pages."
}
finally {
    Pop-Location
}
