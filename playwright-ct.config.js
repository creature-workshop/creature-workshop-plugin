/**
 * @file Playwright component tests of the Desktop pane: each *.ct.jsx under
 * desktop/src mounts a component in Chromium and drives it the way a user
 * would, by role and by text. No screenshots and no DOM snapshots.
 */
import { defineConfig, devices } from '@playwright/experimental-ct-react';

export default defineConfig({
  testDir: './desktop/src',
  testMatch: /.*\.ct\.jsx/,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: process.env.CI ? 'line' : 'list',
  use: {
    ctPort: 3100,
    ctTemplateDir: 'playwright',
    trace: 'on-first-retry',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
