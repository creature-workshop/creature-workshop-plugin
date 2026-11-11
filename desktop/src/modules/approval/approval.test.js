/**
 * @file Recording an approval: what is read from Hermes's plugin list, and
 * what is written to the approved_projects setting.
 */

import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { approvedIn, approveProject, NOT_RECORDED, requestWith } from './approval.js';

/** The answer of `plugins.manage list` with this plugin's approved_projects holding `value`. */
function listing(value) {
  const answer = {
    plugins: [
      { key: 'other', settings_schema: [] },
      { key: 'creature-workshop', settings_schema: [{ key: 'approved_projects', value }] },
    ],
  };
  return answer;
}

/**
 * A stand-in for Hermes's gateway whose plugin list holds `value`, recording
 * each settings write in `writes`.
 */
function gateway(value, writes) {
  return async (method, params) => {
    if (params.action === 'settings') {
      writes.push(params);
    }
    return params.action === 'list' ? listing(value) : { ok: true };
  };
}

afterEach(() => requestWith(() => Promise.reject(new Error('not connected'))));

describe('approvedIn', () => {
  it('reads the roots from this plugin\'s row', () => {
    assert.deepEqual(approvedIn(listing(['/a', '/b'])), ['/a', '/b']);
  });

  it('reads none when the row, the field or a list is missing', () => {
    assert.deepEqual(approvedIn({ plugins: [] }), []);
    assert.deepEqual(approvedIn(listing('/a')), []);
    assert.deepEqual(approvedIn(undefined), []);
  });
});

describe('approveProject', () => {
  it('adds the root after the roots already listed', async () => {
    const writes = [];
    requestWith(gateway(['/a'], writes));
    assert.deepEqual(await approveProject('/b'), { ok: true, data: { listed: ['/a', '/b'] } });
    const write = {
      action: 'settings',
      key: 'creature-workshop',
      values: { approved_projects: ['/a', '/b'] },
    };
    assert.deepEqual(writes, [write]);
  });

  it('writes nothing when the root is listed already', async () => {
    const writes = [];
    requestWith(gateway(['/a'], writes));
    assert.deepEqual(await approveProject('/a'), { ok: true, data: { listed: ['/a'] } });
    assert.deepEqual(writes, []);
  });

  it('answers a failure that says the setting was not saved', async () => {
    requestWith(() => Promise.reject(new Error('gateway unavailable')));
    const result = await approveProject('/a');
    assert.equal(result.ok, false);
    assert.equal(result.error.code, NOT_RECORDED);
    assert.match(result.error.message, /didn't save the approved_projects setting: gateway unavailable/);
  });
});
