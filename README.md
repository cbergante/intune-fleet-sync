# Intune Fleet Sync

A PowerShell command-line tool to preview and request synchronization for an Intune-managed Windows fleet through Microsoft Graph.

**Preview is the default. Add `-Execute` to send sync requests.** An accepted request is not evidence that the device finished syncing or installed an application.

## Requirements

- PowerShell 7.2 or later (`pwsh`), Git, and optionally VS Code with Microsoft's PowerShell extension.
- An active Intune license in the target tenant.
- A work/school account with Intune access to the target devices and Remote tasks / Sync devices permission for execution.
- Microsoft Graph PowerShell modules installed from PowerShell Gallery.
- Microsoft Graph delegated permission `DeviceManagementManagedDevices.Read.All` to retrieve inventory, plus `DeviceManagementManagedDevices.PrivilegedOperations.All` to execute sync. An authorized administrator must approve required consent.
- This starter targets the Microsoft Graph global cloud with interactive sign-in. App-only authentication and national clouds are not implemented.

## Install

Download and extract this repository, or clone it using its GitHub URL. Open its folder in VS Code and select a **PowerShell 7** terminal. Run:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
```

No local administrator session is needed for CurrentUser module installation. The script does not silently install dependencies or change execution policy.

## Find your tenant ID

In Microsoft Entra admin center, open Identity > Overview and copy the Tenant ID. Use that GUID in place of the placeholder below. Do not use a client's tenant ID in public examples.

## Preview Windows 11 devices

```powershell
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000'
```

Sign in to the requested tenant. Review the displayed account, tenant, device names, and generated CSV. Preview requests read-only Graph permissions and does not submit sync actions.

## Request sync for the entire Windows 11 fleet

```powershell
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -Execute
```

Each matching Intune record is processed sequentially. No fleet-size limit is imposed by this script; Graph service limits and throttling still apply. The Graph SDK handles its standard retry policy; requests still failing afterward are logged and processing continues. A final terminating error indicates that one or more requests failed.

## Other examples

```powershell
# Only Windows 11 records that checked in within the previous 30 days
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -LastSeenDays 30 -Execute

# All Windows devices, including Windows 10
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -Target AllWindows -Execute

# Show intended actions without sending them
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -Execute -WhatIf

# Ask for confirmation for each device
./Sync-IntuneFleet.ps1 -TenantId '00000000-0000-0000-0000-000000000000' -Execute -Confirm
```

## Parameters

| Parameter | Purpose | Default |
| --- | --- | --- |
| TenantId | Required tenant GUID; connection is verified | Required |
| Target | Windows11 or AllWindows | Windows11 |
| Execute | Submit sync requests | Off: preview only |
| LastSeenDays | Optional check-in age filter, 1–3650 days | No age filter |
| DelayMilliseconds | Delay between attempted requests | 500 |
| OutputDirectory | CSV report folder | logs beside the script |
| WhatIf / Confirm | Standard PowerShell action controls | Off |

## Target selection and limits

Windows 11 currently reports OS version 10.0 with build 22000 or higher. Selection uses Intune's recorded Windows OS and version, not live endpoint interrogation. Missing or invalid version values are excluded from Windows11 selection. Review preview output before executing. This build heuristic should be reassessed for future Windows releases.

Every matching device record is included unless LastSeenDays is specified. Stale or duplicate enrollment records can appear. Devices must be online and able to reach Intune to process the request. This tool does not poll for completion, force a reboot, or guarantee app deployment success.

CSV statuses: Preview (no request), Requested (API call accepted), Failed (API error), Skipped (WhatIf or declined confirmation). LastSyncBeforeRequest is the inventory value observed before the action, not a completion timestamp.

## Troubleshooting

- **Module not found:** Install both modules in the same PowerShell 7 environment used to run the script.
- **Admin approval required:** Have an authorized tenant administrator consent to the required Graph delegated permissions.
- **403 / access denied:** Check Graph consent and Intune RBAC, scope groups, and scope tags.
- **Throttling / 429:** Increase DelayMilliseconds and examine failures after SDK retries. Do not repeatedly launch parallel fleet-wide runs.
- **No devices:** Verify the tenant, account visibility, recorded OS versions, and any LastSeenDays filter.
- **Execution blocked:** Follow your organization's approved script execution/signing policy.
- **No check-in update:** Check device connectivity and Intune device action status. Accepted requests do not prove completion.

The tool uses a process-scoped interactive Graph connection and disconnects it on completion; use a dedicated terminal if other Graph scripts are running.

## Publish from VS Code

1. Extract this starter and open the folder with File > Open Folder.
2. Review LICENSE before publication; MIT permits others to use, modify, and redistribute the code. Confirm that you have rights to publish it.
3. Open Source Control, choose Initialize Repository, inspect the files, and commit with `Initial Intune Fleet Sync tool`.
4. Choose Publish to GitHub, sign in, and publish a private repository first if you want a review before public release.
5. Use `intune-fleet-sync` as the repository name and `Preview and request Intune sync for Windows fleets using Microsoft Graph PowerShell` as its description.
6. Inspect the published files. Never upload logs, tokens, credentials, real device lists, or client information.
7. Run the validation workflow and test preview plus one controlled device before describing the tool as production tested.
8. After validation, tag a release such as v0.1.0 and describe what was validated. Suggested topics: powershell, intune, microsoft-graph, windows11, endpoint-management.

For an existing tools repository, place this project in a dedicated folder. Merge its ignore rules into the repository's root .gitignore and adapt workflow paths so unrelated scripts are not unintentionally included.

## Validation status

Starter prepared with documentation and a GitHub Actions syntax/static-analysis workflow. It has not been executed against a live tenant or validated locally with PowerShell. CI performs static checks only and never authenticates to Microsoft Graph. No CI credentials are needed. Validate target selection, tenant isolation, permissions, and a controlled sync before broad operational use.

## References

- [Graph syncDevice action and permissions](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-syncdevice?view=graph-rest-1.0)
- [Intune sync action](https://learn.microsoft.com/en-us/intune/device-management/actions/sync)
- [Get managed devices](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.devicemanagement/get-mgdevicemanagementmanageddevice)

## License and contributions

MIT; see LICENSE. See CONTRIBUTING.md and SECURITY.md. No affiliation with or endorsement by Microsoft is implied.
