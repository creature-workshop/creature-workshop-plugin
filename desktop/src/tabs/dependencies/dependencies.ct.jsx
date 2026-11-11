/**
 * @file What a user sees on the Dependencies tab: the tools the project
 * declares, under the channel that installs each, with its version and
 * whether it is installed; a count above them; an Explain button on each
 * tool that asks the model why the project has it; and what the tab says while
 * it checks, when it cannot check, and when the project declares nothing.
 * The tests mount the stories in DependenciesPanel.story.jsx.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { CheckFailsOnce, CheckSaysNothing, Declared, DeclaredLater, NoneDeclared, StillChecking } from './DependenciesPanel.story.jsx';

test('each channel is a group named after it, holding its tools in the order declared', async ({ mount }) => {
  const component = await mount(<Declared />);

  const panel = component.getByRole('tabpanel', { name: 'Dependencies' });
  await expect(panel.getByRole('region', { name: 'system' }).getByRole('term')).toHaveText(['ffmpeg', 'uv']);
  await expect(panel.getByRole('region', { name: 'npm' }).getByRole('term')).toHaveText(['pnpm']);
  await expect(panel.getByRole('region', { name: 'script' }).getByRole('term')).toHaveText(['hermes']);
});

test('each tool shows its declared version and whether it is installed', async ({ mount }) => {
  const component = await mount(<Declared />);

  await expect(component.getByRole('group', { name: 'ffmpeg' }).getByRole('definition')).toHaveText('6.1.1InstalledExplain');
  await expect(component.getByRole('group', { name: 'uv' }).getByRole('definition')).toHaveText('0.11.19MissingExplain');
});

test('the line above the groups counts the dependencies and the missing ones', async ({ mount }) => {
  const component = await mount(<Declared />);

  await expect(component.getByRole('status')).toHaveText('4 dependencies, 1 missing');
});

test('with nothing missing, the line says all are installed', async ({ mount }) => {
  const component = await mount(<Declared missing={[]} />);

  await expect(component.getByRole('status')).toHaveText('4 dependencies, all installed');
});

test('the list shows before the check answers, each tool saying Checking', async ({ mount }) => {
  const component = await mount(<StillChecking />);

  await expect(component.getByRole('status')).toHaveText('4 dependencies');
  await expect(component.getByRole('group', { name: 'pnpm' }).getByRole('definition')).toContainText('12.18.0Checking');
});

test('a check that fails says so above the list, and Try again checks again', async ({ mount }) => {
  const component = await mount(<CheckFailsOnce />);

  const alert = component.getByRole('alert');
  await expect(alert).toContainText("I couldn't check which of these are installed.");
  await expect(component.getByRole('group', { name: 'uv' }).getByRole('definition')).toHaveText('0.11.19Explain');
  await alert.getByRole('button', { name: 'Try again' }).click();

  await expect(component.getByRole('alert')).toHaveCount(0);
  await expect(component.getByRole('status')).toHaveText('4 dependencies, all installed');
});

test('a check that says nothing about the tools says so, and the tools show no status', async ({ mount }) => {
  const component = await mount(<CheckSaysNothing />);

  await expect(component.getByText("I couldn't tell which of these are installed")).toBeVisible();
  await expect(component.getByRole('group', { name: 'ffmpeg' }).getByRole('definition')).toHaveText('6.1.1Explain');
});

test('a project that declares no tools says where they go', async ({ mount }) => {
  const component = await mount(<NoneDeclared />);

  await expect(component.getByRole('tabpanel', { name: 'Dependencies' })).toHaveText('This project declares no dependencies yet. They go in .ops/config/tools.yaml.');
});

test('tools declared outside the pane show within 5 seconds, checked', async ({ mount, page }) => {
  await page.clock.install();
  const component = await mount(<DeclaredLater />);

  await expect(component.getByRole('tabpanel', { name: 'Dependencies' })).toContainText('This project declares no dependencies yet.');
  await page.clock.runFor(5_000);

  await expect(component.getByRole('status')).toHaveText('4 dependencies, all installed');
  await expect(component.getByRole('group', { name: 'pnpm' }).getByRole('definition')).toHaveText('12.18.0InstalledExplain');
});

test('a group heading folds its tools away', async ({ mount }) => {
  const component = await mount(<Declared />);

  await component.getByRole('button', { name: 'system' }).click();

  await expect(component.getByRole('group', { name: 'ffmpeg' })).toHaveCount(0);
  await expect(component.getByRole('group', { name: 'pnpm' })).toBeVisible();
});

test('Explain asks the model about that tool and shows its answer under the row, marked with the model that gave it', async ({ mount }) => {
  const asked = [];
  const component = await mount(<Declared onExplain={(path) => asked.push(path)} />);

  const row = component.getByRole('group', { name: 'ffmpeg' });
  await row.getByRole('button', { name: 'Explain ffmpeg' }).click();

  await expect(row.getByText('rec runs ffmpeg to record every session.')).toBeVisible();
  await expect(row.getByText('Model suggestion, from stepfun/step-3.7-flash:free')).toBeVisible();
  await expect(row.getByRole('button', { name: 'Explain ffmpeg' })).toHaveCount(0);
  await expect(component.getByRole('button', { name: 'Explain uv' })).toBeVisible();
  expect(asked).toEqual(['/project/dependencies/explain?root=%2Fhome%2Fsomeone%2Fnotes&tool=ffmpeg']);
});

test('the explanation sits under the row\'s first line', async ({ mount }) => {
  const component = await mount(<Declared />);

  const row = component.getByRole('group', { name: 'ffmpeg' });
  await row.getByRole('button', { name: 'Explain ffmpeg' }).click();
  const name = await row.getByRole('term').boundingBox();
  const text = await row.getByText('rec runs ffmpeg to record every session.').boundingBox();

  expect(text.y).toBeGreaterThanOrEqual(name.y + name.height);
});

test('when the model gives no explanation the row says so, shows why on request, and Try again asks again', async ({ mount }) => {
  const component = await mount(<Declared unexplained />);

  const row = component.getByRole('group', { name: 'pnpm' });
  await row.getByRole('button', { name: 'Explain pnpm' }).click();
  await expect(row.getByRole('alert')).toContainText("I couldn't get an explanation of pnpm.");
  await expect(row.getByText('Error code: 400')).toHaveCount(0);
  await row.getByRole('button', { name: 'Show details' }).click();
  await expect(row.getByText("'additionalProperties' must be explicitly set to false")).toBeVisible();
  await row.getByRole('button', { name: 'Try again' }).click();

  await expect(row.getByText('rec runs pnpm to record every session.')).toBeVisible();
  await expect(row.getByRole('alert')).toHaveCount(0);
});
