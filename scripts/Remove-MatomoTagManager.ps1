<#
.SYNOPSIS
    Removes the Matomo Tag Manager SPFx Application Customizer from SharePoint Online.

.DESCRIPTION
    Cleanly uninstalls the Matomo Tag Manager extension:
    - Tenant-wide: removes the Tenant Wide Extensions list entry and retracts the package
    - Site-level: removes the Custom Action, uninstalls and retracts the app

.PARAMETER SiteUrl
    The SharePoint Online site URL.
    For tenant-wide: the tenant admin URL (e.g., https://demo-admin.sharepoint.com)
    For site-level: the target site URL

.PARAMETER TenantWide
    Switch to remove the tenant-wide deployment.

.PARAMETER AppCatalogUrl
    (Tenant-wide only) URL of the App Catalog site collection.

.PARAMETER RemovePackage
    Also remove the .sppkg package from the App Catalog. Default: $false

.PARAMETER ClientId
    The Client ID (Application ID) of the Entra ID app registration used by PnP PowerShell.
    Required since September 2024. See: https://pnp.github.io/powershell/articles/registerapplication.html

.EXAMPLE
    # Remove tenant-wide deployment
    .\Remove-MatomoTagManager.ps1 `
        -SiteUrl "https://demo-admin.sharepoint.com" `
        -AppCatalogUrl "https://demo.sharepoint.com/sites/appcatalog" `
        -ClientId "your-client-id-here" `
        -TenantWide -RemovePackage

.EXAMPLE
    # Remove site-level deployment
    .\Remove-MatomoTagManager.ps1 `
        -SiteUrl "https://demo.sharepoint.com/sites/your-site" `
        -ClientId "your-client-id-here" `
        -RemovePackage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [switch]$TenantWide,

    [Parameter(Mandatory = $false)]
    [string]$AppCatalogUrl,

    [Parameter(Mandatory = $false)]
    [switch]$RemovePackage,

    [Parameter(Mandatory = $true)]
    [string]$ClientId
)

$ErrorActionPreference = "Stop"

# Constants - must match the manifest
$ComponentId = "f0e1d2c3-b4a5-4f6e-8d7c-9b0a1e2f3d4c"
$SolutionName = "matomo-tag-manager-client-side-solution"

if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Error "PnP.PowerShell module is required. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
    exit 1
}

# -------------------------------------------------------------------
# Tenant-wide removal
# -------------------------------------------------------------------
if ($TenantWide) {
    if (-not $AppCatalogUrl) {
        Write-Error "The -AppCatalogUrl parameter is required for tenant-wide removal."
        exit 1
    }

    Write-Host "=== Tenant-wide removal ===" -ForegroundColor Cyan

    # Remove Tenant Wide Extensions entry
    Write-Host "Connecting to App Catalog site: $AppCatalogUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $AppCatalogUrl -Interactive -ClientId $ClientId

    Write-Host "Looking for Tenant Wide Extensions entries..." -ForegroundColor Yellow
    $items = Get-PnPListItem -List "Tenant Wide Extensions" | Where-Object {
        $_["TenantWideExtensionComponentId"] -eq $ComponentId
    }

    if ($items) {
        foreach ($item in $items) {
            Write-Host "Removing Tenant Wide Extensions entry (ID: $($item.Id))..." -ForegroundColor Yellow
            Remove-PnPListItem -List "Tenant Wide Extensions" -Identity $item.Id -Force
        }
        Write-Host "Tenant Wide Extensions entries removed." -ForegroundColor Green
    } else {
        Write-Host "No Tenant Wide Extensions entry found for this component." -ForegroundColor Yellow
    }

    # Remove package from Tenant App Catalog
    if ($RemovePackage) {
        Write-Host "Connecting to tenant admin: $SiteUrl" -ForegroundColor Yellow
        Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId

        Write-Host "Retracting and removing package from Tenant App Catalog..." -ForegroundColor Yellow
        $app = Get-PnPApp -Scope Tenant | Where-Object { $_.Title -eq $SolutionName }
        if ($app) {
            Remove-PnPApp -Identity $app.Id -Scope Tenant
            Write-Host "Package removed from Tenant App Catalog." -ForegroundColor Green
        } else {
            Write-Host "Package not found in Tenant App Catalog." -ForegroundColor Yellow
        }
    }

    Write-Host "`nTenant-wide removal complete!" -ForegroundColor Green
    Write-Host "It may take up to 20 minutes for the extension to disappear from all sites." -ForegroundColor Yellow
}
# -------------------------------------------------------------------
# Site-level removal
# -------------------------------------------------------------------
else {
    Write-Host "=== Site-level removal ===" -ForegroundColor Cyan

    Write-Host "Connecting to site: $SiteUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId

    # Remove Custom Action
    Write-Host "Looking for Custom Action..." -ForegroundColor Yellow
    $actions = Get-PnPCustomAction -Scope Site | Where-Object {
        $_.ClientSideComponentId -eq $ComponentId
    }

    if ($actions) {
        foreach ($action in $actions) {
            Write-Host "Removing Custom Action (ID: $($action.Id))..." -ForegroundColor Yellow
            Remove-PnPCustomAction -Identity $action.Id -Scope Site -Force
        }
        Write-Host "Custom Action(s) removed." -ForegroundColor Green
    } else {
        Write-Host "No Custom Action found for this component." -ForegroundColor Yellow
    }

    # Uninstall and remove app
    if ($RemovePackage) {
        Write-Host "Uninstalling and removing app..." -ForegroundColor Yellow
        $app = Get-PnPApp -Scope Site | Where-Object { $_.Title -eq $SolutionName }
        if ($app) {
            Uninstall-PnPApp -Identity $app.Id -Scope Site
            Start-Sleep -Seconds 5
            Remove-PnPApp -Identity $app.Id -Scope Site
            Write-Host "App uninstalled and removed from Site Collection App Catalog." -ForegroundColor Green
        } else {
            Write-Host "App not found in Site Collection App Catalog." -ForegroundColor Yellow
        }
    }

    Write-Host "`nSite-level removal complete!" -ForegroundColor Green
}

Disconnect-PnPOnline
