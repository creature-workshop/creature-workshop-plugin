/**
 * @file The Dependencies tab's data: grouping by channel, each tool's
 * status, and the summary line.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { channelsOf, statusOf, summaryOf, uncheckable } from './dependencies.js';

/** Three declared tools over two channels. */
const DECLARED = [
  { channel: 'system', tool: 'ffmpeg', version: '6.1.1' },
  { channel: 'npm', tool: 'pnpm', version: '12.18.0' },
  { channel: 'system', tool: 'uv', version: '0.11.19' },
];

/** The check while it runs. */
const CHECKING = { state: 'loading' };

/**
 * A finished check whose rows say which of the tools are installed.
 *
 * @param {Record<string, boolean>} installed Whether each tool is installed, by name.
 */
function checked(installed) {
  const rows = Object.entries(installed).map(([tool, here]) => ({ tool, version: '', channel: '', installed: here }));
  return { state: 'success', data: { ok: true, rows, stderr: '', duration_ms: 1 } };
}

describe('channelsOf', () => {
  it('groups the tools by channel, channels and tools in the order declared', () => {
    const groups = channelsOf(DECLARED, CHECKING);
    assert.deepEqual(groups.map((group) => [group.channel, group.tools.map((tool) => tool.tool)]), [['system', ['ffmpeg', 'uv']], ['npm', ['pnpm']]]);
  });

  it('gives each tool its version and its status', () => {
    const [system] = channelsOf(DECLARED, checked({ ffmpeg: true, uv: false, pnpm: true }));
    assert.deepEqual(system.tools, [
      { tool: 'ffmpeg', version: '6.1.1', status: 'installed' },
      { tool: 'uv', version: '0.11.19', status: 'missing' },
    ]);
  });
});

describe('statusOf', () => {
  it('is checking while the check runs', () => {
    assert.equal(statusOf('uv', CHECKING), 'checking');
  });

  it('is unknown when the check failed, was not run, or has no row for the tool', () => {
    assert.equal(statusOf('uv', { state: 'failure', error: {} }), 'unknown');
    assert.equal(statusOf('uv', { state: 'success', data: null }), 'unknown');
    assert.equal(statusOf('uv', checked({ ffmpeg: true })), 'unknown');
  });
});

describe('summaryOf', () => {
  it('counts the dependencies and the missing ones', () => {
    assert.equal(summaryOf(channelsOf(DECLARED, checked({ ffmpeg: true, uv: false, pnpm: true }))), '3 dependencies, 1 missing');
    assert.equal(summaryOf(channelsOf(DECLARED, checked({ ffmpeg: true, uv: true, pnpm: true }))), '3 dependencies, all installed');
  });

  it('gives the count alone until every status is known', () => {
    assert.equal(summaryOf(channelsOf(DECLARED, CHECKING)), '3 dependencies');
    assert.equal(summaryOf(channelsOf(DECLARED.slice(0, 1), checked({}))), '1 dependency');
  });
});

describe('uncheckable', () => {
  it('is true when a finished check says nothing about any tool', () => {
    assert.equal(uncheckable(checked({}), channelsOf(DECLARED, checked({}))), true);
  });

  it('is false while the check runs, when it has a row, and with no tools', () => {
    assert.equal(uncheckable(CHECKING, channelsOf(DECLARED, CHECKING)), false);
    assert.equal(uncheckable(checked({ uv: true }), channelsOf(DECLARED, checked({ uv: true }))), false);
    assert.equal(uncheckable(checked({}), []), false);
  });
});
