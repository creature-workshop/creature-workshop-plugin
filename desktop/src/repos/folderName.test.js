/**
 * @file The name a checkout goes by.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { folderName } from './folderName.js';

describe('folderName', () => {
  it('is the last part of the path, with or without a trailing slash', () => {
    assert.equal(folderName('/home/someone/notes'), 'notes');
    assert.equal(folderName('/home/someone/notes/'), 'notes');
  });
});
