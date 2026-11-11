/**
 * @file When a header label keeps its qualifier.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { qualifierFits } from './labelFit.js';

describe('qualifierFits', () => {
  it('keeps the qualifier when it, the name, the gap and the (i) fit the row', () => {
    assert.equal(qualifierFits({ row: 138, tip: 24, qualifier: 50, name: 60 }), true);
  });

  it('drops the qualifier when they are a pixel too wide', () => {
    assert.equal(qualifierFits({ row: 137, tip: 24, qualifier: 50, name: 60 }), false);
  });
});
