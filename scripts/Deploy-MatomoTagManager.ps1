<#
.SYNOPSIS
    Deploys the Matomo Tag Manager SPFx Application Customizer to SharePoint Online.

.DESCRIPTION
    Uploads the .sppkg package to the App Catalog and registers the extension
    with the specified Matomo Tag Manager container URL.

    Supports two deployment modes:
    - Tenant-wide: deploys via Tenant App Catalog + Tenant Wide Extensions list
    - Site-level: deploys via Site Collection App Catalog + Custom Action

    The script is idempotent: it removes any existing registration before reinstalling.

.PARAMETER SiteUrl
    The SharePoint Online site URL.
    For tenant-wide: the tenant admin URL (e.g., https://demo-admin.sharepoint.com)
    For site-level: the target site URL (e.g., https://demo.sharepoint.com/sites/mysite)

.PARAMETER ContainerUrl
    The full URL of the Matomo Tag Manager container JS file.
    Example: https://matomo.example.com/js/container_AbCdEf12.js

.PARAMETER TenantWide
    Switch to deploy tenant-wide via the Tenant App Catalog and Tenant Wide Extensions list.

.PARAMETER PackagePath
    Path to the .sppkg file. Defaults to ./sharepoint/solution/matomo-tag-manager.sppkg

.PARAMETER AppCatalogUrl
    (Tenant-wide only) URL of the App Catalog site collection.
    Required when using -TenantWide to add the entry to the Tenant Wide Extensions list.
    Example: https://demo.sharepoint.com/sites/appcatalog

.PARAMETER ClientId
    The Client ID (Application ID) of the Entra ID app registration used by PnP PowerShell.
    Required since September 2024. See: https://pnp.github.io/powershell/articles/registerapplication.html

.EXAMPLE
    # Tenant-wide deployment
    .\Deploy-MatomoTagManager.ps1 `
        -SiteUrl "https://demo-admin.sharepoint.com" `
        -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js" `
        -AppCatalogUrl "https://demo.sharepoint.com/sites/appcatalog" `
        -ClientId "your-client-id-here" `
        -TenantWide

.EXAMPLE
    # Site-level deployment
    .\Deploy-MatomoTagManager.ps1 `
        -SiteUrl "https://demo.sharepoint.com/sites/marketing" `
        -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js" `
        -ClientId "your-client-id-here"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('\/container_[a-zA-Z0-9_]+\.js(\?.*)?$')]
    [string]$ContainerUrl,

    [Parameter(Mandatory = $false)]
    [switch]$TenantWide,

    [Parameter(Mandatory = $false)]
    [string]$PackagePath = (Join-Path $PSScriptRoot "..\sharepoint\solution\matomo-tag-manager.sppkg"),

    [Parameter(Mandatory = $false)]
    [string]$AppCatalogUrl,

    [Parameter(Mandatory = $true)]
    [string]$ClientId
)

$ErrorActionPreference = "Stop"

# Constants - must match the manifest
$ComponentId = "f0e1d2c3-b4a5-4f6e-8d7c-9b0a1e2f3d4c"
$CustomActionName = "MatomoTagManager"
$ClientSideComponentProperties = @{ containerUrl = $ContainerUrl } | ConvertTo-Json -Compress

# -------------------------------------------------------------------
# Validate prerequisites
# -------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Error "PnP.PowerShell module is required. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
    exit 1
}

if (-not (Test-Path $PackagePath)) {
    Write-Error "Package not found at '$PackagePath'. Run 'npm run package' first to build the .sppkg."
    exit 1
}

if ($TenantWide -and -not $AppCatalogUrl) {
    Write-Error "The -AppCatalogUrl parameter is required for tenant-wide deployment."
    exit 1
}

# -------------------------------------------------------------------
# Tenant-wide deployment
# -------------------------------------------------------------------
if ($TenantWide) {
    Write-Host "=== Tenant-wide deployment ===" -ForegroundColor Cyan

    # Step 1 - Upload & deploy the package to the Tenant App Catalog
    Write-Host "Connecting to tenant admin: $SiteUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId

    Write-Host "Uploading package to Tenant App Catalog..." -ForegroundColor Yellow
    $app = Add-PnPApp -Path $PackagePath -Scope Tenant -Overwrite -Publish
    Write-Host "Package uploaded and published. App ID: $($app.Id)" -ForegroundColor Green

    # Step 2 - Add/update entry in the Tenant Wide Extensions list
    Write-Host "Connecting to App Catalog site: $AppCatalogUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $AppCatalogUrl -Interactive -ClientId $ClientId

    # Remove existing entry if present (idempotent)
    Write-Host "Checking for existing Tenant Wide Extensions entry..." -ForegroundColor Yellow
    $existingItems = Get-PnPListItem -List "Tenant Wide Extensions" | Where-Object {
        $_["TenantWideExtensionComponentId"] -eq $ComponentId
    }
    foreach ($item in $existingItems) {
        Write-Host "Removing existing entry (ID: $($item.Id))..." -ForegroundColor Yellow
        Remove-PnPListItem -List "Tenant Wide Extensions" -Identity $item.Id -Force
    }

    # Add new entry
    Write-Host "Adding Tenant Wide Extensions entry..." -ForegroundColor Yellow
    Add-PnPListItem -List "Tenant Wide Extensions" -Values @{
        Title                                = "Matomo Tag Manager"
        TenantWideExtensionComponentId       = $ComponentId
        TenantWideExtensionComponentProperties = $ClientSideComponentProperties
        TenantWideExtensionLocation          = "ClientSideExtension.ApplicationCustomizer"
        TenantWideExtensionDisabled          = $false
    } | Out-Null

    Write-Host "`nTenant-wide deployment complete!" -ForegroundColor Green
    Write-Host "The extension may take up to 20 minutes to propagate across all sites." -ForegroundColor Yellow
}
# -------------------------------------------------------------------
# Site-level deployment
# -------------------------------------------------------------------
else {
    Write-Host "=== Site-level deployment ===" -ForegroundColor Cyan

    Write-Host "Connecting to site: $SiteUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId

    # Step 1 - Upload & install the package to the Site Collection App Catalog
    Write-Host "Uploading package to Site Collection App Catalog..." -ForegroundColor Yellow
    $app = Add-PnPApp -Path $PackagePath -Scope Site -Overwrite -Publish

    Write-Host "Installing app on site..." -ForegroundColor Yellow
    Install-PnPApp -Identity $app.Id -Scope Site -ErrorAction SilentlyContinue

    # Step 2 - Remove existing Custom Action if present (idempotent)
    Write-Host "Checking for existing Custom Action..." -ForegroundColor Yellow
    $existingActions = Get-PnPCustomAction -Scope Site | Where-Object {
        $_.ClientSideComponentId -eq $ComponentId
    }
    foreach ($action in $existingActions) {
        Write-Host "Removing existing Custom Action (ID: $($action.Id))..." -ForegroundColor Yellow
        Remove-PnPCustomAction -Identity $action.Id -Scope Site -Force
    }

    # Step 3 - Register the Custom Action
    Write-Host "Registering Custom Action with container URL..." -ForegroundColor Yellow
    Add-PnPCustomAction `
        -Name $CustomActionName `
        -Title "Matomo Tag Manager" `
        -Location "ClientSideExtension.ApplicationCustomizer" `
        -ClientSideComponentId $ComponentId `
        -ClientSideComponentProperties $ClientSideComponentProperties `
        -Scope Site

    Write-Host "`nSite-level deployment complete!" -ForegroundColor Green
    Write-Host "Container URL: $ContainerUrl" -ForegroundColor Yellow
}

Disconnect-PnPOnline
