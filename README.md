# Matomo Tag Manager for SharePoint Online

SPFx Application Customizer that injects a **Matomo Tag Manager (MTM)** container on all modern SharePoint Online pages.

Inspired by Julien Chable's [Matomo Analytics SPFx solution](https://gitlab.lsonline.fr/SharePoint/sp-dev-fx-webparts/matomo), this project replaces the classic `_paq.push` tracker with the full Matomo Tag Manager container approach.

## Features

- Injects the standard MTM container snippet on every modern page
- Single `containerUrl` parameter (full URL to the container JS file)
- URL format validation (`/js/container_*.js`)
- SPA-safe: prevents double injection during SharePoint client-side navigation
- `skipFeatureDeployment: true` for tenant-wide deployment
- PowerShell scripts for deployment, removal, and classic pages support

## Prerequisites

- [Node.js](https://nodejs.org/) v18.x
- SharePoint Online environment
- [PnP.PowerShell](https://pnp.github.io/powershell/) for deployment scripts

## Build

```bash
npm install
npm run package
```

This produces `sharepoint/solution/matomo-tag-manager.sppkg`.

## Deploy

### Modern Pages - Tenant-wide

```powershell
.\scripts\Deploy-MatomoTagManager.ps1 `
    -SiteUrl "https://contoso-admin.sharepoint.com" `
    -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js" `
    -AppCatalogUrl "https://contoso.sharepoint.com/sites/appcatalog" `
    -TenantWide
```

### Modern Pages - Site-level

```powershell
.\scripts\Deploy-MatomoTagManager.ps1 `
    -SiteUrl "https://contoso.sharepoint.com/sites/marketing" `
    -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js"
```

### Classic Pages (no SPFx required)

```powershell
.\scripts\Deploy-MatomoTagManager-Classic.ps1 `
    -SiteUrl "https://contoso.sharepoint.com/sites/classic-site" `
    -ContainerUrl "https://matomo.example.com/js/container_AbCdEf12.js"
```

> **Note:** Classic pages deployment requires [Custom Script](https://learn.microsoft.com/en-us/sharepoint/allow-or-prevent-custom-script) to be allowed on the target site.

## Remove

```powershell
# Tenant-wide
.\scripts\Remove-MatomoTagManager.ps1 `
    -SiteUrl "https://contoso-admin.sharepoint.com" `
    -AppCatalogUrl "https://contoso.sharepoint.com/sites/appcatalog" `
    -TenantWide -RemovePackage

# Site-level
.\scripts\Remove-MatomoTagManager.ps1 `
    -SiteUrl "https://contoso.sharepoint.com/sites/marketing" `
    -RemovePackage
```

## Configuration

The extension accepts a single property via `ClientSideComponentProperties`:

| Property       | Type   | Description                                                         |
|----------------|--------|---------------------------------------------------------------------|
| `containerUrl` | string | Full URL to the MTM container JS (e.g., `https://matomo.example.com/js/container_AbCdEf12.js`) |

## Debug

Update `config/serve.json` with your SharePoint site URL, then:

```bash
gulp serve
```

## Project Structure

```
├── config/                          # SPFx build configuration
├── scripts/
│   ├── Deploy-MatomoTagManager.ps1          # Modern pages deployment (PnP PowerShell)
│   ├── Remove-MatomoTagManager.ps1          # Clean removal script
│   └── Deploy-MatomoTagManager-Classic.ps1  # Classic pages deployment (ScriptLink)
├── src/extensions/matomoTagManager/
│   ├── MatomoTagManagerApplicationCustomizer.manifest.json
│   └── MatomoTagManagerApplicationCustomizer.ts
├── package.json
└── tsconfig.json
```

## SPFx Version

Built with **SPFx 1.20** (SharePoint Framework).

## License

MIT
