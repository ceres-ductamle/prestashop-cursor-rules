<#
.SYNOPSIS
    Syncs canonical .mdc rule files into every PrestaShop repo's .cursor\rules\ folder.

.DESCRIPTION
    This folder (_cursor-rules) is the single source of truth for Cursor AI rules
    applied across every PrestaShop module and PrestaShop-adjacent repo under
    C:\Users\Windows 10\projects\prestashop. Edit the .mdc files here, then run
    this script to propagate them to each repo.

    Each repo receives a COPY (not a link) so the rules travel with git.
    Existing .cursor\rules\*.mdc in a target repo that match a canonical file
    are overwritten. Files in target repos that do not exist in the canonical
    folder are left alone (repos may carry their own project-specific rules).

.PARAMETER Target
    Optional. Specific repo folder name(s) to sync. Defaults to all matching repos.

.PARAMETER DryRun
    Optional. Print what would be copied without writing anything.

.EXAMPLE
    # Sync all eligible repos
    .\sync-rules.ps1

.EXAMPLE
    # Preview only
    .\sync-rules.ps1 -DryRun

.EXAMPLE
    # Sync a single repo
    .\sync-rules.ps1 -Target Prestashop-Cdiscount
#>
[CmdletBinding()]
param(
    [string[]]$Target,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectsRoot = Split-Path -Parent $ScriptRoot

# Repos that should receive the canonical ruleset.
# Pattern = folder-name prefix to match under $ProjectsRoot.
$IncludePatterns = @(
    'FeedBiz-*',
    'Mirakl-*',
    'Prestashop-*',
    'PrestaShop-*'
)

# Repos that must NOT receive a specific rule (empty = all repos get every canonical rule).
# Project-specific rules live in that repo's own .cursor/rules/ — not in this canonical folder.
$ExcludeByRule = @{}

# Copy a rule only to named repos (empty = every canonical rule goes to all target repos).
$IncludeByRule = @{
    'module-ignore-seller-partner.mdc' = @(
        'Prestashop-Amazon',
        'Prestashop-SAAS-Module'
    )
}

# Renamed or removed rules — deleted from every target repo on sync.
$ObsoleteRules = @(
    'prestashop-compat.mdc',
    'sql-safety.mdc',
    'logging.mdc',
    'translations.mdc',
    'upgrade-files.mdc',
    'no-direct-octopia.mdc',
    'octopia-yaml-cite.mdc',
    'module-octopia-proxy.mdc',
    'module-octopia-yaml.mdc',
    'changelog.mdc',
    'code-optimize.mdc',
    'ignore-vendor.mdc'
)

$canonicalRules = Get-ChildItem -Path $ScriptRoot -Filter '*.mdc' -File
if ($canonicalRules.Count -eq 0) {
    Write-Error "No .mdc files found in $ScriptRoot"
    exit 1
}

Write-Host "Canonical rules ($($canonicalRules.Count)):" -ForegroundColor Cyan
$canonicalRules | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""

# Resolve target repo list
$allRepos = Get-ChildItem -Path $ProjectsRoot -Directory | Where-Object {
    $name = $_.Name
    $matchInclude = $IncludePatterns | Where-Object { $name -like $_ } | Select-Object -First 1
    $null -ne $matchInclude
}

if ($Target) {
    $allRepos = $allRepos | Where-Object { $Target -contains $_.Name }
    if ($allRepos.Count -eq 0) {
        Write-Error "No matching repos for -Target $($Target -join ', ')"
        exit 1
    }
}

Write-Host "Target repos ($($allRepos.Count)):" -ForegroundColor Cyan
$allRepos | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""

$copied = 0
$skipped = 0

foreach ($repo in $allRepos) {
    $rulesDir = Join-Path $repo.FullName '.cursor\rules'

    if (-not (Test-Path $rulesDir)) {
        if ($DryRun) {
            Write-Host "[DRY] mkdir $rulesDir" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
        }
    }

    foreach ($rule in $canonicalRules) {
        $excluded = $ExcludeByRule[$rule.Name]
        if ($excluded -and $excluded -contains $repo.Name) {
            Write-Host "  skip  $($repo.Name)\$($rule.Name) (excluded)" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $includedOnly = $IncludeByRule[$rule.Name]
        if ($includedOnly -and $includedOnly -notcontains $repo.Name) {
            $destPath = Join-Path $rulesDir $rule.Name
            if (Test-Path $destPath) {
                if ($DryRun) {
                    Write-Host "[DRY] prune $($repo.Name)\$($rule.Name) (not in IncludeByRule)" -ForegroundColor Yellow
                } else {
                    Remove-Item -Path $destPath -Force
                    Write-Host "  prune $($repo.Name)\$($rule.Name) (not in IncludeByRule)" -ForegroundColor Magenta
                }
                $copied++
            } else {
                Write-Host "  skip  $($repo.Name)\$($rule.Name) (not in IncludeByRule)" -ForegroundColor DarkGray
                $skipped++
            }
            continue
        }

        $destPath = Join-Path $rulesDir $rule.Name
        $shouldCopy = $true
        if (Test-Path $destPath) {
            $srcHash  = (Get-FileHash $rule.FullName -Algorithm SHA256).Hash
            $destHash = (Get-FileHash $destPath -Algorithm SHA256).Hash
            if ($srcHash -eq $destHash) {
                $shouldCopy = $false
                Write-Host "  same  $($repo.Name)\$($rule.Name)" -ForegroundColor DarkGray
                $skipped++
            }
        }

        if ($shouldCopy) {
            if ($DryRun) {
                Write-Host "[DRY] copy  $($repo.Name)\$($rule.Name)" -ForegroundColor Yellow
            } else {
                Copy-Item -Path $rule.FullName -Destination $destPath -Force
                Write-Host "  copy  $($repo.Name)\$($rule.Name)" -ForegroundColor Green
            }
            $copied++
        }
    }

    foreach ($obsolete in $ObsoleteRules) {
        $obsoletePath = Join-Path $rulesDir $obsolete
        if (Test-Path $obsoletePath) {
            if ($DryRun) {
                Write-Host "[DRY] retire $($repo.Name)\$obsolete" -ForegroundColor Yellow
            } else {
                Remove-Item -Path $obsoletePath -Force
                Write-Host "  retire $($repo.Name)\$obsolete" -ForegroundColor Magenta
            }
            $copied++
        }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "DRY RUN — $copied would copy, $skipped would skip." -ForegroundColor Yellow
} else {
    Write-Host "Done — $copied copied, $skipped unchanged." -ForegroundColor Cyan
}
