/**
 * @file Playwright component tests of the Desktop pane: each *.ct.jsx under
 * desktop/src mounts a component in Chromium and drives it the way a user
 * would, by role and by text. No screenshots and no DOM snapshots. The page
 * each test mounts into is template/, beside this file, and what Playwright
 * builds from it goes under .ops/cache/playwright. The SDK Desktop provides
 * does not exist outside Desktop, so its name resolves to plugin-sdk.js
 * beside this file, a stand-in built on the same radix-ui primitives. The
 * JSX compiles against the pane's own runtime, as the bundle does: the
 * name `@workshop/jsx` resolves to desktop/src/bind, and the React plugin is given
 * here, with that import source, in place of the one Playwright adds.
 */

import { fileURLToPath } from 'node:url';
import { defineConfig, devices } from '@playwright/experimental-ct-react';
import react from '@vitejs/plugin-react';

/** The name the JSX transform imports the pane's runtime from. */
const JSX_SOURCE = '@workshop/jsx';

/** What the names that are not packages resolve to: the SDK's stand-in, and the folder of the pane's JSX runtime. */
const ALIASES = {
  '@hermes/plugin-sdk': fileURLToPath(new URL('./plugin-sdk.js', import.meta.url)),
  [JSX_SOURCE]: fileURLToPath(new URL('../../../desktop/src/bind', import.meta.url)),
};

/** The runner's configuration: the tests under desktop/src, one worker, Chromium. */
export default defineConfig({
  testDir: '../../../desktop/src',
  outputDir: '../../cache/playwright/test-results',
  testMatch: /.*\.ct\.jsx/,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: process.env.CI ? 'line' : 'list',
  use: {
    ctPort: 3100,
    ctTemplateDir: 'template',
    ctCacheDir: '../../cache/playwright/ct',
    ctViteConfig: { plugins: [react({ jsxImportSource: JSX_SOURCE })], resolve: { alias: ALIASES } },
    trace: 'on-first-retry',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
