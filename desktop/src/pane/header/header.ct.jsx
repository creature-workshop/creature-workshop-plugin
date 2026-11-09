/**
 * @file What a user sees in the header: that no git repository was found,
 * the one repository's name and state, or a selector over several that
 * shows the selected one's state; and that it follows the focused session. The tests mount the header's stories and read it
 * by role and by text, never by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Empty, Following, Several, Single } from './Header.story.jsx';

test('a directory with no git repository says so', async ({ mount }) => {
  const component = await mount(<Empty />);

  await expect(component.getByRole('banner', { name: 'Project' })).toHaveText('No repositories detected');
});

test('a directory with one repository shows its name and its state like a prompt', async ({ mount }) => {
  const component = await mount(<Single />);

  const header = component.getByRole('banner', { name: 'Project' });
  await expect(header.getByText('demo', { exact: true })).toBeVisible();
  await expect(header.getByText('main ↑2 +1 ?3')).toHaveAttribute('title', 'main, 2 ahead, 1 staged, 3 untracked');
  await expect(header.getByRole('combobox')).toHaveCount(0);
});

test('a directory with several repositories offers a selector, with none selected at first', async ({ mount }) => {
  const component = await mount(<Several />);

  const selector = component.getByRole('combobox', { name: 'Repository' });
  await expect(selector).toHaveText('Select a repository');
  await expect(component.getByText('✓')).toHaveCount(0);
});

test('selecting a repository shows its state beside the selector', async ({ mount, page }) => {
  const component = await mount(<Several />);

  await component.getByRole('combobox', { name: 'Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();

  await expect(component.getByRole('combobox', { name: 'Repository' })).toHaveText('site');
  await expect(component.getByText('feat/x ✓')).toBeVisible();
});

test('focusing another session shows its folder and drops the selection', async ({ mount, page }) => {
  const component = await mount(<Following />);

  await component.getByRole('combobox', { name: 'Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();
  await expect(component.getByText('feat/x ✓')).toBeVisible();

  await component.update(<Following second />);
  await expect(component.getByRole('banner', { name: 'Project' })).toHaveText('No repositories detected');

  await component.update(<Following />);
  await expect(component.getByRole('combobox', { name: 'Repository' })).toHaveText('Select a repository');
});
