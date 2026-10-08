#Requires -Version 7.2
<#
.SYNOPSIS
Preview or request Intune sync for a Windows fleet.
.DESCRIPTION
Uses delegated Microsoft Graph authentication. Defaults to preview only.
Windows11 selects Windows version 10.0 with build 22000 or greater.
.EXAMPLE
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000'
.EXAMPLE
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -Execute
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [ValidateSet('Windows11','AllWindows')][string]$Target = 'Windows11',
    [switch]$Execute,
    [ValidateRange(1,3650)][int]$LastSeenDays,
    [ValidateRange(0,60000)][int]$DelayMilliseconds = 500,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'logs')
)
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop
$scopes = @('DeviceManagementManagedDevices.Read.All')
if ($Execute -and -not $WhatIfPreference) {
    $scopes += 'DeviceManagementManagedDevices.PrivilegedOperations.All'
}
# A process-scoped connection avoids reusing a cached connection to another tenant.
Connect-MgGraph -TenantId $TenantId.ToString() -Scopes $scopes -ContextScope Process -NoWelcome
try {
    $context = Get-MgContext
    if ($context.TenantId -ne $TenantId.ToString()) { throw 'Connected tenant does not match requested tenant.' }
    Write-Host "Tenant: $($context.TenantId) | Account: $($context.Account)"
    $windows = @(Get-MgDeviceManagementManagedDevice -All -Filter "operatingSystem eq 'Windows'" -Property Id,DeviceName,OperatingSystem,OSVersion,LastSyncDateTime)
    $devices = @($windows | Where-Object {
        $version = $null
        $matchesOS = $Target -eq 'AllWindows' -or (
            [version]::TryParse($_.OSVersion, [ref]$version) -and
            $version.Major -eq 10 -and $version.Minor -eq 0 -and $version.Build -ge 22000
        )
        $matchesDate = -not $LastSeenDays -or (
            $_.LastSyncDateTime -and $_.LastSyncDateTime -ge [datetimeoffset]::UtcNow.AddDays(-$LastSeenDays)
        )
        $matchesOS -and $matchesDate
    })
    Write-Host "Target: $Target | Matching device records: $($devices.Count)"
    if ($devices.Count -eq 0) { Write-Host 'No matching devices. No requests sent.'; return }
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $report = Join-Path $OutputDirectory ("sync-{0}-{1}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N').Substring(0,8))
    $requested = 0
    $failed = 0
    foreach ($device in $devices) {
        $status = 'Preview'
        $message = ''
        if ($Execute) {
            if ($PSCmdlet.ShouldProcess("$($device.DeviceName) [$($device.Id)] in tenant $TenantId", 'Request Intune sync')) {
                try {
                    Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -ErrorAction Stop
                    $status = 'Requested'
                    $requested++
                } catch {
                    $status = 'Failed'
                    $message = $_.Exception.Message
                    $failed++
                    Write-Warning "Failed: $($device.DeviceName): $message"
                }
                Start-Sleep -Milliseconds $DelayMilliseconds
            } else { $status = 'Skipped' }
        }
        # Write each result immediately so an interrupted run retains earlier results.
        [pscustomobject]@{
            TimestampUtc = [datetimeoffset]::UtcNow.ToString('o')
            TenantId = $TenantId.ToString()
            DeviceId = $device.Id
            DeviceName = $device.DeviceName
            OSVersion = $device.OSVersion
            LastSyncBeforeRequest = $device.LastSyncDateTime
            Status = $status
            Error = $message
        } | Export-Csv -LiteralPath $report -NoTypeInformation -Append -Encoding utf8
        Write-Host "$status : $($device.DeviceName)"
    }
    Write-Host "Requested: $requested | Failed: $failed | Report: $report"
    if ($failed -gt 0) { throw "$failed sync requests failed. Review the CSV report." }
} finally {
    Disconnect-MgGraph | Out-Null
}
