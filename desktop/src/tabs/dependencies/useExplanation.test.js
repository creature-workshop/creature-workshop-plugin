/**
 * @file How asking for an explanation ends: the text, or the details of why there is none.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { explanationOf } from './useExplanation.js';

describe('explanationOf', () => {
  it('is explained with the text and the model that gave it', () => {
    const result = { ok: true, data: { found: true, explanation: 'rec records through ffmpeg.', reason: '', model: 'stepfun/step-3.7-flash:free' } };
    assert.deepEqual(explanationOf(result), { phase: 'explained', text: 'rec records through ffmpeg.', model: 'stepfun/step-3.7-flash:free' });
  });

  it('has no model when the backend names none', () => {
    const result = { ok: true, data: { found: true, explanation: 'x', reason: '' } };
    assert.equal(explanationOf(result).model, '');
  });

  it('is failed with the backend\'s reason when the model gave none', () => {
    const result = { ok: true, data: { found: false, explanation: '', reason: 'Error code: 400 - the schema was refused' } };
    assert.deepEqual(explanationOf(result), { phase: 'failed', details: 'Error code: 400 - the schema was refused' });
  });

  it('is failed with the error\'s code, status and message when the call itself failed', () => {
    const result = { ok: false, error: { code: 'NOT_FOUND', status: 404, message: 'Not Found' } };
    assert.deepEqual(explanationOf(result), { phase: 'failed', details: 'code: NOT_FOUND\nstatus: 404\nmessage: Not Found' });
  });
});
