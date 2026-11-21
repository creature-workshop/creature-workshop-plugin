/**
 * @file The stand-in's GET /repos/file-state: it answers the state `none`
 * for the file asked about, without asking the story's own backend.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { standIn } from './index.js';

describe('the stand-in file state', () => {
  it('answers none for the root and the path asked about', async () => {
    const rest = standIn(async () => { throw new Error('the story was asked'); });
    const answer = await rest('/repos/file-state?root=%2Fhome%2Fsomeone%2Fnotes&path=%2Fhome%2Fsomeone%2Fnotes%2F.ops%2Fconfig%2Fmanifest.yaml');
    assert.deepEqual(answer, { root: '/home/someone/notes', path: '/home/someone/notes/.ops/config/manifest.yaml', state: 'none' });
  });
});
