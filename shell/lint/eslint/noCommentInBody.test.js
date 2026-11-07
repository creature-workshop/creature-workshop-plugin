/**
 * @file house/no-comment-in-body over the fixtures under
 * tests/fixtures/no_comment_in_body/: comments above declarations and an
 * ESLint directive in a body pass, and a comment in a body fails on its line.
 */
import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './noCommentInBody.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('no-comment-in-body', rule, {
  valid: [fixture('no_comment_in_body', 'clean.js')],
  invalid: [
    { ...fixture('no_comment_in_body', 'commented.js'), errors: [{ messageId: 'inside', data: { name: 'addOne' }, line: 7 }, { messageId: 'inside', data: { name: 'double' }, line: 12 }] },
  ],
});
