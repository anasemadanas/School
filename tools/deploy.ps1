<#
.SYNOPSIS
    Deploys the School Management database with sqlcmd (runs sql/00_run_all.sql).

.DESCRIPTION
    -Clean drops the target database first, but ONLY when its name is one this
    project owns (SchoolManagement or SchoolManagement_*). Any other database
    name is refused, so no unrelated database can be dropped by this script.

.EXAMPLE
    ./tools/deploy.ps1 -Server 'lpc:.\SQLEXPRESS' -DatabaseName SchoolManagement_Validation -Clean
#>
param(
    [string] $Server       = 'lpc:.\SQLEXPRESS',
    [string] $DatabaseName = 'SchoolManagement',
    [switch] $Clean,
    [string] $Sqlcmd       = 'sqlcmd',
    [string] $LogFile      = ''
)

$ErrorActionPreference = 'Stop'
if ($DatabaseName -notmatch '^SchoolManagement(_[A-Za-z0-9]+)?$') {
    throw "Refusing to deploy to '$DatabaseName': only SchoolManagement or SchoolManagement_<suffix> are allowed."
}

$sqlDir = Join-Path $PSScriptRoot '..\sql' | Resolve-Path

if ($Clean) {
    $drop = "IF DB_ID(N'$DatabaseName') IS NOT NULL BEGIN ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DatabaseName]; END"
    & $Sqlcmd -S $Server -E -C -b -Q $drop
    if ($LASTEXITCODE -ne 0) { throw "Dropping $DatabaseName failed." }
    Write-Host "Dropped $DatabaseName (if it existed)."
}

Push-Location $sqlDir
try {
    $args = @('-S', $Server, '-E', '-C', '-b', '-W', '-s', '|', '-v', "DatabaseName=$DatabaseName", '-i', '00_run_all.sql')
    if ($LogFile) { & $Sqlcmd @args *> $LogFile } else { & $Sqlcmd @args }
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($code -ne 0) { throw "Deployment failed (sqlcmd exit code $code)." }
Write-Host "Deployment of $DatabaseName succeeded."
