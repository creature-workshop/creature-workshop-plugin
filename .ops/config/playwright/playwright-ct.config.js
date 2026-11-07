/**
 * @file Playwright component tests of the Desktop pane: each *.ct.jsx under
 * desktop/src mounts a component in Chromium and drives it the way a user
 * would, by role and by text. No screenshots and no DOM snapshots. The page
 * each test mounts into is template/, beside this file, and what Playwright
 * builds from it goes under .ops/cache/playwright.
 */
import { defineConfig, devices } from '@playwright/experimental-ct-react';

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
    trace: 'on-first-retry',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
