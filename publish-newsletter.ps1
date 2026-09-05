param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFile,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$IssueDate,

    [Parameter(Mandatory = $false)]
    [string]$PdfSourceFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = $PSScriptRoot
$archiveDirectory = Join-Path $repositoryRoot 'archive'
$archiveFile = Join-Path $archiveDirectory "$IssueDate.html"
$archiveIndexFile = Join-Path $archiveDirectory 'index.html'
$latestFile = Join-Path $repositoryRoot 'index.html'
$resolvedSource = (Resolve-Path -LiteralPath $SourceFile).Path
$pdfDirectory = Join-Path $repositoryRoot 'pdf'
$pdfArchiveFile = Join-Path $pdfDirectory "$IssueDate.pdf"
$pdfLatestFile = Join-Path $pdfDirectory 'latest.pdf'

New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
Copy-Item -LiteralPath $resolvedSource -Destination $archiveFile -Force
Copy-Item -LiteralPath $resolvedSource -Destination $latestFile -Force
if ($PdfSourceFile) {
    $resolvedPdfSource = (Resolve-Path -LiteralPath $PdfSourceFile).Path
    New-Item -ItemType Directory -Path $pdfDirectory -Force | Out-Null
    Copy-Item -LiteralPath $resolvedPdfSource -Destination $pdfArchiveFile -Force
    Copy-Item -LiteralPath $resolvedPdfSource -Destination $pdfLatestFile -Force
}

$dayNames = @('일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일')
$archiveItems = Get-ChildItem -LiteralPath $archiveDirectory -File -Filter '*.html' |
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}$' } |
    Sort-Object BaseName -Descending
$archiveLinks = foreach ($item in $archiveItems) {
    $issue = [datetime]::ParseExact($item.BaseName, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $label = '{0}년 {1}월 {2}일 {3}' -f $issue.Year, $issue.Month, $issue.Day, $dayNames[[int]$issue.DayOfWeek]
    "<li><time datetime=`"$($item.BaseName)`">$label</time><a href=`"$($item.Name)`" target=`"_blank`" rel=`"noopener noreferrer`">해당 호 보기</a></li>"
}
$archiveIndex = @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>배터리 마스터 | 지난 뉴스레터</title>
<style>
:root{--ink:#111;--blue:#2563eb;--line:#d4d4d4;--soft:#f5f5f5}*{box-sizing:border-box}html{background:var(--soft);-webkit-text-size-adjust:100%}body{margin:0;color:var(--ink);font-family:Pretendard,Arial,"Noto Sans KR","Malgun Gothic",sans-serif;font-size:16px;line-height:1.6;word-break:keep-all;overflow-wrap:anywhere}.wrap{width:min(calc(100% - 32px),920px);margin:24px auto;padding:32px 38px;background:#fff;border-top:7px solid var(--ink)}.eyebrow{margin:0 0 8px;color:var(--blue);font-size:13px;font-weight:800}h1{margin:0;font-size:clamp(30px,5vw,48px);letter-spacing:-.06em;line-height:1.15}.intro{margin:12px 0 26px;color:#555}.latest{display:inline-flex;align-items:center;min-height:44px;padding:8px 14px;background:var(--blue);color:#fff;font-weight:800;text-decoration:none}ul{list-style:none;margin:28px 0 0;padding:0;border-top:2px solid var(--ink)}li{display:grid;grid-template-columns:minmax(0,1fr) 120px;gap:16px;align-items:center;padding:15px 0;border-bottom:1px solid var(--line)}time{font-size:18px;font-weight:800}li a{display:flex;align-items:center;justify-content:center;min-height:44px;border:1px solid var(--blue);color:var(--blue);font-size:14px;font-weight:750;text-decoration:none}footer{margin-top:28px;padding-top:12px;border-top:4px solid var(--ink);font-size:13px;color:#555}@media(max-width:720px){html,body{background:#fff}.wrap{width:100%;margin:0;padding:20px 16px 28px}li{grid-template-columns:1fr}li a{width:100%}}@page{size:A4 portrait;margin:12mm}@media print{html{background:#fff}.wrap{width:auto;margin:0;padding:0;border-top-width:4px}li{break-inside:avoid}.latest{border:1px solid var(--blue);color:var(--blue);background:#fff}}
</style>
</head>
<body>
<main class="wrap">
<p class="eyebrow">한국배터리아카데미 남부권캠퍼스 · (재)포항테크노파크</p>
<h1>지난 뉴스레터</h1>
<p class="intro">날짜별 배터리 산업·채용 뉴스레터를 최신순으로 확인할 수 있어요.</p>
<a class="latest" href="../" target="_blank" rel="noopener noreferrer">최신 뉴스레터 보기</a>
<ul>
$($archiveLinks -join "`n")
</ul>
<footer>보관 주소: https://batterybrief.pages.dev/archive/</footer>
</main>
</body>
</html>
"@
[IO.File]::WriteAllText($archiveIndexFile, $archiveIndex, [Text.UTF8Encoding]::new($false))

Push-Location $repositoryRoot
try {
    $gitPaths = @('index.html', "archive/$IssueDate.html", 'archive/index.html', 'publish-newsletter.ps1')
    if ($PdfSourceFile) {
        $gitPaths += @("pdf/$IssueDate.pdf", 'pdf/latest.pdf')
    }
    git add -- $gitPaths
    $pendingChanges = git status --porcelain -- $gitPaths
    if ($pendingChanges) {
        git commit -m "Publish battery newsletter $IssueDate"
        git push origin main
    }
    else {
        Write-Output "No Git changes to publish for $IssueDate."
    }

    $deploymentDirectory = Join-Path $repositoryRoot '.pages-output'
    $deploymentArchive = Join-Path $deploymentDirectory 'archive'
    $deploymentPdf = Join-Path $deploymentDirectory 'pdf'
    New-Item -ItemType Directory -Path $deploymentArchive -Force | Out-Null
    New-Item -ItemType Directory -Path $deploymentPdf -Force | Out-Null
    Copy-Item -LiteralPath $latestFile -Destination (Join-Path $deploymentDirectory 'index.html') -Force
    Copy-Item -Path (Join-Path $archiveDirectory '*') -Destination $deploymentArchive -Force
    if (Test-Path -LiteralPath $pdfDirectory) {
        Copy-Item -Path (Join-Path $pdfDirectory '*') -Destination $deploymentPdf -Force
    }

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
