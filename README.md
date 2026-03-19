# Matomo Tag Manager for SharePoint Online

SPFx Application Customizer that injects a **Matomo Tag Manager (MTM)** container on all modern SharePoint Online pages.

## Features

- Injects the standard MTM container snippet on every modern SharePoint Online page
- Supports classic pages via a separate ScriptLink deployment (no SPFx required)
- SPA-safe: prevents double injection during client-side navigation
- URL validation: only accepts valid Matomo container URLs (`/container_*.js`)
- Tenant-wide or site-level deployment via PnP PowerShell scripts

## Getting Started

### 1. Install prerequisites

- [Node.js](https://nodejs.org/) v18+ (tested up to v24, but v18 recommended for production build)
- [PnP.PowerShell](https://pnp.github.io/powershell/) for deployment scripts:

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

### 2. Register an Entra ID application

Since September 2024, PnP PowerShell requires your own [Entra ID (Azure AD) app registration](https://pnp.github.io/powershell/articles/registerapplication.html).

```powershell
Register-PnPEntraIDAppForInteractiveLogin `
    -ApplicationName "PnP.PowerShell" `
    -Tenant demo.onmicrosoft.com `
    -SharePointDelegatePermissions "AllSites.FullControl"
```

This registers the app with the required SharePoint permissions and prompts for admin consent automatically. Note the **Client ID** returned — you will need it for all deployment scripts.

> **Note:** You need the **Application Developer** (or Global Administrator) role to create the app registration.

If you register the app manually in the Azure Portal, make sure to:

1. Add the API permission **SharePoint > AllSites.FullControl** (delegated) and grant admin consent
2. Add the platform **Mobile and desktop applications** with redirect URI `http://localhost`

### 3. Build the package

```bash
npm install
npm run package
```

This produces `sharepoint/solution/matomo-tag-manager.sppkg`.

### 4. Get your Matomo container URL

In your Matomo instance, go to **Tag Manager > Container > Install Code** and copy the container URL. It looks like:

```
https://matomo.example.com/js/container_XXXXXXXX.js
```

### 5. Deploy

> **Tip:** If PowerShell blocks script execution, you can bypass the policy for the current session:
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

Choose one of the following deployment methods:

#### Which method should I use?

| Method | Scope | Container | Requires |
|---|---|---|---|
| **Site-level** | A single site collection | One container per site | Site Collection App Catalog on the target site |
| **Tenant-wide** | All sites in the tenant | Same container everywhere | Tenant Admin URL + Tenant App Catalog |
| **Classic pages** | Classic pages on a single site | One container per site | Custom Script allowed on the target site |

**Site-level is recommended** — it allows a different Matomo container per site, so each site has its own tracking configuration.

Tenant-wide deploys the **same container URL on all sites** of the tenant. Use it only if you want a single Matomo container for everything.

#### Modern Pages - Site-level (recommended)

Site-level deployment requires a **Site Collection App Catalog** on the target site. This is a local app catalog scoped to one site — it does **not** exist by default and must be created by a SharePoint admin:

```powershell
Connect-PnPOnline -Url "https://demo-admin.sharepoint.com" -Interactive -ClientId "your-client-id-here"
Add-PnPSiteCollectionAppCatalog -Site "https://demo.sharepoint.com/sites/marketing"
```

> If you get a **403 error** on `Add-PnPApp`, it means the Site Collection App Catalog has not been created on that site.

Then deploy:

```powershell
.\scripts\Deploy-MatomoTagManager.ps1 `
    -SiteUrl "https://demo.sharepoint.com/sites/marketing" `
    -ContainerUrl "https://matomo.example.com/js/container_XXXXXXXX.js" `
    -ClientId "your-client-id-here"
```

#### Modern Pages - Tenant-wide

```powershell
.\scripts\Deploy-MatomoTagManager.ps1 `
    -SiteUrl "https://demo-admin.sharepoint.com" `
    -ContainerUrl "https://matomo.example.com/js/container_XXXXXXXX.js" `
    -AppCatalogUrl "https://demo.sharepoint.com/sites/appcatalog" `
    -ClientId "your-client-id-here" `
    -TenantWide
```

#### Classic Pages (no SPFx required)

```powershell
.\scripts\Deploy-MatomoTagManager-Classic.ps1 `
    -SiteUrl "https://demo.sharepoint.com/sites/classic-site" `
    -ContainerUrl "https://matomo.example.com/js/container_XXXXXXXX.js" `
    -ClientId "your-client-id-here"
```

> **Note:** Classic pages deployment requires [Custom Script](https://learn.microsoft.com/en-us/sharepoint/allow-or-prevent-custom-script) to be allowed on the target site.

## Remove

### Tenant-wide

```powershell
.\scripts\Remove-MatomoTagManager.ps1 `
    -SiteUrl "https://demo-admin.sharepoint.com" `
    -AppCatalogUrl "https://demo.sharepoint.com/sites/appcatalog" `
    -ClientId "your-client-id-here" `
    -TenantWide -RemovePackage
```

### Site-level

```powershell
.\scripts\Remove-MatomoTagManager.ps1 `
    -SiteUrl "https://demo.sharepoint.com/sites/marketing" `
    -ClientId "your-client-id-here" `
    -RemovePackage
```

## Configuration

The extension accepts a single property via `ClientSideComponentProperties`:

| Property       | Type   | Description                                                                                    |
|----------------|--------|------------------------------------------------------------------------------------------------|
| `containerUrl` | string | Full URL to the MTM container JS (e.g., `https://matomo.example.com/js/container_XXXXXXXX.js`) |

## Debug

Edit `config/serve.json` to match your environment:

1. Replace `pageUrl` with a real SharePoint Online page URL
2. Replace `containerUrl` with your Matomo Tag Manager container URL

```json
{
  "serveConfigurations": {
    "default": {
      "pageUrl": "https://your-tenant.sharepoint.com/sites/your-site/SitePages/Home.aspx",
      "customActions": {
        "f0e1d2c3-b4a5-4f6e-8d7c-9b0a1e2f3d4c": {
          "location": "ClientSideExtension.ApplicationCustomizer",
          "properties": {
            "containerUrl": "https://your-matomo.example.com/js/container_XXXXXXXX.js"
          }
        }
      }
    }
  }
}
```

Then run:

```bash
gulp serve
```

This opens the page with `?loadSPFX=true&debugManifestsFile=...` query parameters, loading the extension from your local dev server.

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
