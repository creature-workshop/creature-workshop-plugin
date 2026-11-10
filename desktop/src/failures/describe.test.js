/**
 * @file What the pane says about a failure: each code is sorted by whose
 * problem it is, the codes the backend's message does not explain get
 * their own why, the others use the message, each gets a hint of what to
 * try, and the details list the code,
 * the status and the raw message.
 */

import { describe as suite, it } from 'node:test';
import assert from 'node:assert/strict';
import { describe, detailsOf } from './describe.js';

suite('describe', () => {
  it('explains the codes whose message means nothing to the user', () => {
    for (const code of ['UNREACHABLE', 'NO_ROUTE', 'INTERNAL']) {
      const { why, hint } = describe({ code, status: 0, message: 'raw' });
      assert.ok(why && hint && why !== 'raw', code);
    }
  });

  it('sorts each code by whose problem it is', () => {
    const kinds = Object.fromEntries(
      ['UNREACHABLE', 'NO_ROUTE', 'INTERNAL', 'UNSUPPORTED', 'NOT_FOUND', 'REFUSED', 'NEW'].map((code) => [code, describe({ code, message: 'raw' }).kind]),
    );
    assert.deepEqual(kinds, {
      UNREACHABLE: 'passing',
      NO_ROUTE: 'yours',
      INTERNAL: 'bug',
      UNSUPPORTED: 'bug',
      NOT_FOUND: 'yours',
      REFUSED: 'yours',
      NEW: 'passing',
    });
  });

  it("uses the backend's message as why for the codes whose message explains itself, with a hint of what to try", () => {
    assert.deepEqual(describe({ code: 'NOT_FOUND', status: 404, message: 'No repository at /tmp/gone.' }), {
      kind: 'yours',
      why: 'No repository at /tmp/gone.',
      hint: 'Check that it exists in this repository, then try again.',
    });
  });

  it('asks the user to tell the intake address about a bug', () => {
    assert.match(describe({ code: 'INTERNAL', status: 500, message: 'raw' }).hint, /requests@creature-workshop\.com/);
  });

  it('lists the code, the status and the raw message as the details', () => {
    assert.equal(detailsOf({ code: 'INTERNAL', status: 500, message: "KeyError: 'root'" }), "code: INTERNAL\nstatus: 500\nmessage: KeyError: 'root'");
  });
});
