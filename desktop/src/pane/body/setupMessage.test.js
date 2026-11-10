/**
 * @file What the pane says about a checkout in each setup state.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setupMessage } from './setupMessage.js';

describe('setupMessage', () => {
  it('says a branch without .ops/config has no workshop', () => {
    assert.equal(setupMessage('no-workshop', 'notes').what, "notes doesn't have a workshop yet.");
  });

  it('says a checkout without shellops is not set up, and names .ops/boot', () => {
    const message = setupMessage('not-set-up', 'notes-fix');
    assert.equal(message.what, "notes-fix isn't set up yet.");
    assert.equal(message.code, '.ops/boot');
  });

  it('says nothing about a ready checkout, or a state it does not know', () => {
    assert.equal(setupMessage('ready', 'notes'), null);
    assert.equal(setupMessage('later', 'notes'), null);
  });
});
