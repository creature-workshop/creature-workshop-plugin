/**
 * @file What a user can do with the pane: read the toolchain, switch tabs,
 * see why there is nothing to show outside a project, and see the toolchain
 * change after a refresh. Each test mounts the harness over the backend's
 * answers and reads the page by role and text, never by a test id; the last
 * mounts a component that throws inside the pane's boundary.
 */
import { test, expect } from '@playwright/experimental-ct-react';
import { Broken } from './Broken.jsx';
import { PaneBoundary } from './PaneBoundary.jsx';
import { PaneHarness } from './PaneHarness.jsx';

/**
 * The backend's answer, GET /project, for a project that declares two tools,
 * one of them missing: a workshop.answers.Project as the pane receives it, with
 * nothing of Hermes's own state in it.
 */
const ANSWER = {
  found: true,
  root: '/home/someone/demo',
  name: 'Demo',
  summary: 'This directory is the shellops project "Demo"; it declares 2 tools.',
  declaration: {
    'manifest.yaml': 'name: Demo\n',
    'tools.yaml': 'system:\n  ffmpeg:\n    version: 6.1.1\n  rsync:\n    version: 3.2.7\n',
  },
  release: { latest: '0.1.0-dev.1', stable: '0.0.0' },
  refresh_seconds: 5,
  declared: [
    { channel: 'system', tool: 'ffmpeg', version: '6.1.1' },
    { channel: 'system', tool: 'rsync', version: '3.2.7' },
  ],
  toolchain: {
    ok: false,
    rows: [
      { tool: 'ffmpeg', version: '6.1.1', channel: 'system', installed: true },
      { tool: 'rsync', version: '3.2.7', channel: 'system', installed: false },
    ],
    stderr: '',
    duration_ms: 12,
  },
};

test('the toolchain tab lists every declared tool with its state, and the chip counts them', async ({ mount }) => {
  const component = await mount(<PaneHarness answer={ANSWER} cwd="/home/someone/demo" />);

  await expect(component.getByText('1 of 2 declared tools installed')).toBeVisible();
  await expect(component.getByText('ffmpeg')).toBeVisible();
  await expect(component.getByText('rsync')).toBeVisible();
  await expect(component.getByRole('status')).toHaveText('toolchain 1/2');
});

test('the Declaration and Release tabs show the files and the release record', async ({ mount }) => {
  const component = await mount(<PaneHarness answer={ANSWER} cwd="/home/someone/demo" />);

  await component.getByRole('button', { name: 'Declaration' }).click();
  await expect(component.getByText('.ops/config/tools.yaml')).toBeVisible();
  await expect(component.getByText('rsync:')).toBeVisible();

  await component.getByRole('button', { name: 'Release' }).click();
  await expect(component.getByText('latest: 0.1.0-dev.1')).toBeVisible();
  await expect(component.getByText('2 tools declared by this project')).toBeVisible();
});

test('outside a project the pane says so and how a project gets one', async ({ mount }) => {
  const component = await mount(<PaneHarness answer={{ found: false }} cwd="/home/someone/elsewhere" />);

  await expect(component.getByText('No shellops project at /home/someone/elsewhere.')).toBeVisible();
  await expect(component.getByText('shell/.ops/init')).toBeVisible();
  await expect(component.getByRole('status')).toHaveText('no .ops here');
});

/** The same project after rsync was installed: what the backend answers once the toolchain changed. */
const ALL_INSTALLED = {
  ...ANSWER,
  toolchain: { ...ANSWER.toolchain, ok: true, rows: ANSWER.toolchain.rows.map((row) => ({ ...row, installed: true })) },
};

test('the pane re-reads the toolchain on the interval the backend answers with', async ({ mount }) => {
  const soon = { ...ANSWER, refresh_seconds: 1 };
  const component = await mount(<PaneHarness answer={soon} later={ALL_INSTALLED} cwd="/home/someone/demo" />);

  await expect(component.getByRole('status')).toHaveText('toolchain 1/2');
  await expect(component.getByRole('status')).toHaveText('toolchain 2/2');
  await expect(component.getByText('2 of 2 declared tools installed')).toBeVisible();
});

test('a component that throws while rendering shows its error instead of taking the pane down', async ({ mount }) => {
  const component = await mount(<PaneBoundary><Broken /></PaneBoundary>);

  await expect(component.getByText('pane error: broken on purpose')).toBeVisible();
});
