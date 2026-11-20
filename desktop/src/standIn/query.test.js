/**
 * @file The stand-in's GET /store/query: a query that names no record
 * answers the story's one record as a list, a query that names a record
 * answers it as the story does, and the story's rejection passes through.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { standIn } from './index.js';

/** The record the story's file holds. */
const RECORD = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes' } });

/** A story's backend call that answers every query with its one record. */
const answering = async () => ({ data: { record: RECORD } });

describe('the stand-in record list', () => {
  it('answers a query without an id with the story’s record as a list', async () => {
    assert.deepEqual(await standIn(answering)('/store/query?kind=file&source=config%2Fmanifest.yaml&id=&revision='), { data: { records: [RECORD] } });
  });

  it('answers a query that names a record as the story does', async () => {
    assert.deepEqual(await standIn(answering)('/store/query?kind=file&source=config%2Fmanifest.yaml&id=document'), { data: { record: RECORD } });
  });

  it('passes the story’s rejection through', async () => {
    const rest = standIn(async () => { throw new Error('never reached the backend'); });
    await assert.rejects(rest('/store/query?id='), /never reached the backend/);
  });
});
