<#
.SYNOPSIS
    Deploys the Matomo Tag Manager tracker on SharePoint classic pages (without SPFx).

.DESCRIPTION
    Injects the Matomo Tag Manager container script on SharePoint classic pages
    using a ScriptLink Custom Action. This does NOT require SPFx and works on
    classic pages where the SPFx Application Customizer does not run.

    The script is idempotent: it removes any existing ScriptLink action before recreating it.

    NOTE: This requires that "Custom Script" is allowed on the target site.
    See: https://learn.microsoft.com/en-us/sharepoint/allow-or-prevent-custom-script

.PARAMETER SiteUrl
    The SharePoint Online site URL (e.g., https://demo.sharepoint.com/sites/mysite)

.PARAMETER ContainerUrl
    The full URL of the Matomo Tag Manager container JS file.
    Example: https://matomo.example.com/js/container_AbCdEf12.js

.PARAMETER Scope
    Where to register the Custom Action: "Site" (site collection) or "Web" (single web).
    Default: Site

.EXAMPLE
    .\Deploy-MatomoTagManager-Classic.ps1 `
        -SiteUrl "https://demo.sharepoint.com/sites/classic-site" `
        -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js"

.EXAMPLE
    # Web-scoped (single subsite only)
    .\Deploy-MatomoTagManager-Classic.ps1 `
        -SiteUrl "https://demo.sharepoint.com/sites/classic-site/subsite" `
        -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js" `
        -Scope Web
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('\/container_[a-zA-Z0-9_]+\.js(\?.*)?$')]
    [string]$ContainerUrl,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Site", "Web")]
    [string]$Scope = "Site"
)

$ErrorActionPreference = "Stop"

$CustomActionName = "MatomoTagManagerClassic"
$CustomActionDescription = "Injects Matomo Tag Manager container on classic SharePoint pages"

# The inline JavaScript that replicates the MTM embed snippet
$ScriptBlock = @"
var _mtm = window._mtm = window._mtm || [];
_mtm.push({'mtm.startTime': (new Date().getTime()), 'event': 'mtm.Start'});
(function() {
    if (document.getElementById('mtm-classic-script')) return;
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.id='mtm-classic-script';
    g.async=true;
    g.src='$ContainerUrl';
    s.parentNode.insertBefore(g,s);
})();
"@

# -------------------------------------------------------------------
# Validate prerequisites
# -------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Error "PnP.PowerShell module is required. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
    exit 1
}

Write-Host "=== Classic pages deployment (ScriptLink) ===" -ForegroundColor Cyan

Write-Host "Connecting to site: $SiteUrl" -ForegroundColor Yellow
Connect-PnPOnline -Url $SiteUrl -Interactive

# Remove existing action if present (idempotent)
Write-Host "Checking for existing ScriptLink Custom Action..." -ForegroundColor Yellow
$existingActions = Get-PnPCustomAction -Scope $Scope | Where-Object {
    $_.Name -eq $CustomActionName
}

foreach ($action in $existingActions) {
    Write-Host "Removing existing Custom Action (ID: $($action.Id))..." -ForegroundColor Yellow
    Remove-PnPCustomAction -Identity $action.Id -Scope $Scope -Force
}

# Register new ScriptLink Custom Action
Write-Host "Registering ScriptLink Custom Action..." -ForegroundColor Yellow
Add-PnPCustomAction `
    -Name $CustomActionName `
    -Title "Matomo Tag Manager (Classic)" `
    -Description $CustomActionDescription `
    -Location "ScriptLink" `
    -ScriptBlock $ScriptBlock `
    -Scope $Scope `
    -Sequence 10000

Write-Host "`nClassic pages deployment complete!" -ForegroundColor Green
Write-Host "Container URL: $ContainerUrl" -ForegroundColor Yellow
Write-Host "Scope: $Scope" -ForegroundColor Yellow

# Verify
Write-Host "`nVerifying registration..." -ForegroundColor Yellow
$verification = Get-PnPCustomAction -Scope $Scope | Where-Object { $_.Name -eq $CustomActionName }
if ($verification) {
    Write-Host "Custom Action registered successfully (ID: $($verification.Id))" -ForegroundColor Green
} else {
    Write-Warning "Custom Action registration could not be verified. Check that Custom Script is allowed on this site."
}

Disconnect-PnPOnline
