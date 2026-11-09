/**
 * @file What a user sees in the pane: a region named Workshop, with a footer
 * that says which build of the plugin this is and which checkout it came
 * from, and keeps the branch alone when the pane is too narrow for both.
 * The tests mount the harness over the backend's answer and read the pane
 * by role and by text, never by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { PaneHarness } from './PaneHarness.jsx';

/** The backend's answer for a checkout on main. */
const ON_MAIN = { version: '0.1.0-dev.9', branch: 'main' };

/**
 * What the footer shows: its text with the hidden measuring copy left out.
 *
 * @param component The mounted pane.
 */
function shown(component) {
  return component.getByRole('contentinfo').evaluate((footer) => {
    const measure = footer.querySelector('[aria-hidden]');
    return footer.textContent.replace(measure.textContent, '').trim();
  });
}

test('the footer shows the version and the branch', async ({ mount }) => {
  const component = await mount(<PaneHarness about={ON_MAIN} />);

  await expect(component.getByRole('region', { name: 'Workshop' })).toBeVisible();
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});

test('the footer shows the version alone outside git', async ({ mount }) => {
  const component = await mount(<PaneHarness about={{ version: '0.1.0-dev.9', branch: '' }} />);

  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9');
});

test('the footer keeps the branch and drops the version when the pane is too narrow for both', async ({ mount }) => {
  const component = await mount(<PaneHarness about={ON_MAIN} width={90} />);

  await expect.poll(() => shown(component)).toBe('main');

  await component.update(<PaneHarness about={ON_MAIN} width={320} />);
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});
