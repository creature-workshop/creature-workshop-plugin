/**
 * @file What a user sees in the pane: a region named Workshop, with a header
 * along its top and a footer along its bottom that says which build of the
 * plugin this is and which checkout it came from, keeping the branch alone
 * when the pane is too narrow for both. The tests mount the pane's stories
 * and read the pane by role and by text, never by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { OnMain, OutsideGit } from './WorkshopPane.story.jsx';

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

test('the header runs along the top of the pane, above the footer', async ({ mount }) => {
  const component = await mount(<OnMain />);

  const header = component.getByRole('banner', { name: 'Project' });
  await expect(header).toHaveText('No repositories detected');
  const top = await header.boundingBox();
  const bottom = await component.getByRole('contentinfo').boundingBox();
  expect(top.y + top.height).toBeLessThanOrEqual(bottom.y);
});

test('the footer shows the version and the branch', async ({ mount }) => {
  const component = await mount(<OnMain />);

  await expect(component.getByRole('region', { name: 'Workshop' })).toBeVisible();
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});

test('the footer shows the version alone outside git', async ({ mount }) => {
  const component = await mount(<OutsideGit />);

  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9');
});

test('the footer keeps the branch and drops the version when the pane is too narrow for both', async ({ mount }) => {
  const component = await mount(<OnMain width={90} />);

  await expect.poll(() => shown(component)).toBe('main');

  await component.update(<OnMain width={320} />);
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});
