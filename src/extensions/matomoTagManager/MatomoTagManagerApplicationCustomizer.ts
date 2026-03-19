import { Log } from '@microsoft/sp-core-library';
import { BaseApplicationCustomizer } from '@microsoft/sp-application-base';

const LOG_SOURCE: string = 'MatomoTagManagerApplicationCustomizer';
const SCRIPT_ID: string = 'mtm-container-script';

export interface IMatomoTagManagerApplicationCustomizerProperties {
  containerUrl: string;
}

/** @internal */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const window: any;

export default class MatomoTagManagerApplicationCustomizer
  extends BaseApplicationCustomizer<IMatomoTagManagerApplicationCustomizerProperties> {

  public onInit(): Promise<void> {
    Log.info(LOG_SOURCE, 'Initializing Matomo Tag Manager Application Customizer');

    const { containerUrl } = this.properties;

    if (!containerUrl) {
      Log.warn(LOG_SOURCE, 'containerUrl property is not configured. Matomo Tag Manager will not be loaded.');
      return Promise.resolve();
    }

    if (!this._isValidContainerUrl(containerUrl)) {
      Log.warn(LOG_SOURCE, `Invalid containerUrl format: "${containerUrl}". Expected URL containing /container_xxx.js`);
      return Promise.resolve();
    }

    // Prevent double injection (SPA navigation in SharePoint Online)
    if (document.getElementById(SCRIPT_ID)) {
      Log.info(LOG_SOURCE, 'Matomo Tag Manager container script already present, skipping injection.');
      return Promise.resolve();
    }

    this._injectMatomoTagManager(containerUrl);

    return Promise.resolve();
  }

  /**
   * Validates that the container URL matches the expected Matomo Tag Manager format.
   * Supports both self-hosted (/js/container_xxx.js) and Matomo Cloud CDN (container_xxx.js) URLs.
   */
  private _isValidContainerUrl(url: string): boolean {
    return /\/container_[a-zA-Z0-9_]+\.js(\?.*)?$/.test(url);
  }

  /**
   * Injects the Matomo Tag Manager container snippet into the page.
   * Equivalent to the standard MTM embed code.
   */
  private _injectMatomoTagManager(containerUrl: string): void {
    // Initialize the _mtm data layer
    window._mtm = window._mtm || [];
    window._mtm.push({ 'mtm.startTime': (new Date().getTime()), 'event': 'mtm.Start' });

    // Create and inject the container script
    const script: HTMLScriptElement = document.createElement('script');
    script.id = SCRIPT_ID;
    script.async = true;
    script.src = containerUrl;

    const firstScript: HTMLScriptElement | null = document.getElementsByTagName('script')[0];
    if (firstScript && firstScript.parentNode) {
      firstScript.parentNode.insertBefore(script, firstScript);
    } else {
      document.head.appendChild(script);
    }

    Log.info(LOG_SOURCE, `Matomo Tag Manager container injected successfully: ${containerUrl}`);
  }
}
