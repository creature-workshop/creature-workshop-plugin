/**
 * @file house/tag-spacing over the fixtures under shell/lint/eslint/fixtures/tag_spacing/:
 * tags together with one blank line before `@returns` pass; a blank line
 * between two parameters, none before `@returns`, and two before it each fail
 * on the tag's line.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './tagSpacing.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('tag-spacing', rule, {
  valid: [fixture('tag_spacing', 'spaced.js')],
  invalid: [
    {
      ...fixture('tag_spacing', 'crowded.js'),
      errors: [
        { messageId: 'together', data: { tag: 'param', blanks: 1 }, line: 8 },
        { messageId: 'apart', data: { tag: 'returns', blanks: 0 }, line: 9 },
        { messageId: 'apart', data: { tag: 'returns', blanks: 2 }, line: 21 },
      ],
    },
  ],
});
