/**
 * @file What a user sees in the header: that no git repository was found,
 * the one repository's name and state, or a selector over several that
 * shows the selected one's state; a worktree selector when a repository
 * has several worktrees; and that it follows the focused session. The
 * tests mount the header's stories and read it by role and by text, never
 * by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Empty, Following, InsideWorktree, Several, Single, Worktrees } from './Header.story.jsx';

test('a directory with no git repository says so', async ({ mount }) => {
  const component = await mount(<Empty />);

  await expect(component.getByRole('banner', { name: 'Project' })).toHaveText('No repositories detected');
});

test('a directory with one repository shows its name and its state like a prompt', async ({ mount }) => {
  const component = await mount(<Single />);

  const header = component.getByRole('banner', { name: 'Project' });
  await expect(header.getByText('demo', { exact: true })).toBeVisible();
  await expect(header.getByText('main ↑2 +1 ?3')).toBeVisible();
  await expect(header.getByRole('combobox')).toHaveCount(0);
});

test('the state says itself in words in the same tooltip as the (i)s, and to assistive technology', async ({ mount, page }) => {
  const component = await mount(<Single />);

  const header = component.getByRole('banner', { name: 'Project' });
  await header.getByText('main ↑2 +1 ?3').hover();

  await expect(page.getByRole('tooltip')).toHaveText('main, 2 ahead, 1 staged, 3 untracked');
  await expect(header.getByText('main, 2 ahead, 1 staged, 3 untracked')).toHaveClass(/sr-only/);
});

test('a directory with several repositories offers a selector, with none selected at first', async ({ mount }) => {
  const component = await mount(<Several />);

  const selector = component.getByRole('combobox', { name: 'Session Repository' });
  await expect(selector).toHaveText('Select a repository');
  await expect(component.getByText('✓')).toHaveCount(0);
});

test('selecting a repository shows its state beside the selector', async ({ mount, page }) => {
  const component = await mount(<Several />);

  await component.getByRole('combobox', { name: 'Session Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();

  await expect(component.getByRole('combobox', { name: 'Session Repository' })).toHaveText('site');
  await expect(component.getByText('feat/x ✓')).toBeVisible();
});

test('focusing another session shows its folder and drops the selection', async ({ mount, page }) => {
  const component = await mount(<Following />);

  await component.getByRole('combobox', { name: 'Session Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();
  await expect(component.getByText('feat/x ✓')).toBeVisible();

  await component.update(<Following second />);
  await expect(component.getByRole('banner', { name: 'Project' })).toHaveText('No repositories detected');

  await component.update(<Following />);
  await expect(component.getByRole('combobox', { name: 'Session Repository' })).toHaveText('Select a repository');
});

test('a repository with only its main worktree has no worktree selector', async ({ mount }) => {
  const component = await mount(<Single />);

  await expect(component.getByText('main ↑2 +1 ?3')).toBeVisible();
  await expect(component.getByRole('combobox', { name: 'Session Worktree' })).toHaveCount(0);
});

test('a repository with several worktrees offers them, the main one selected, each by folder with its branch in parentheses, and the trigger shows the folder alone', async ({ mount, page }) => {
  const component = await mount(<Worktrees />);

  const selector = component.getByRole('combobox', { name: 'Session Worktree' });
  await expect(selector).toHaveText('site');
  await selector.click();

  await expect(page.getByRole('option')).toHaveText(['site (feat/x)', 'site-hotfix (fix/hotfix)', 'site-old (detached at 4444444)']);
});

test('selecting a worktree shows its state', async ({ mount, page }) => {
  const component = await mount(<Worktrees />);

  await expect(component.getByText('feat/x ✓')).toBeVisible();
  await component.getByRole('combobox', { name: 'Session Worktree' }).click();
  await page.getByRole('option', { name: 'site-hotfix (fix/hotfix)' }).click();
  await expect(component.getByRole('combobox', { name: 'Session Worktree' })).toHaveText('site-hotfix');

  await expect(component.getByText('fix/hotfix ~1')).toBeVisible();
});

test('selecting a repository with several worktrees shows the worktree selector beside it', async ({ mount, page }) => {
  const component = await mount(<Several />);

  await expect(component.getByRole('combobox', { name: 'Session Worktree' })).toHaveCount(0);
  await component.getByRole('combobox', { name: 'Session Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();

  await expect(component.getByRole('combobox', { name: 'Session Worktree' })).toHaveText('site');
});

test('a session inside a linked worktree selects its repository and that worktree', async ({ mount }) => {
  const component = await mount(<InsideWorktree />);

  await expect(component.getByText('site', { exact: true })).toBeVisible();
  await expect(component.getByRole('combobox', { name: 'Session Worktree' })).toHaveText('site-hotfix');
  await expect(component.getByText('fix/hotfix ~1')).toBeVisible();
});

test('each selector has a small label above it and a tooltip with the path', async ({ mount, page }) => {
  const component = await mount(<Several />);

  await component.getByRole('combobox', { name: 'Session Repository' }).click();
  await page.getByRole('option', { name: 'site' }).click();
  await expect(component.getByText('Session Repository', { exact: true })).toBeVisible();
  await expect(component.getByText('Session Worktree', { exact: true })).toBeVisible();
  await component.getByRole('combobox', { name: 'Session Worktree' }).hover();

  await expect(page.getByRole('tooltip')).toHaveText('/home/someone/code/site, on feat/x');
});

test('each label has an (i) that says what the selector is for', async ({ mount, page }) => {
  const component = await mount(<Worktrees />);

  await component.getByRole('button', { name: 'About Session Worktree' }).hover();

  await expect(page.getByRole('tooltip')).toHaveText('Which worktree of site would you like to inspect?');
});
