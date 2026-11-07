/**
 * @file house/declarations-first over the fixtures under
 * tests/fixtures/declarations_first/: constants above the functions pass,
 * and each variable declared after the first function fails.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './declarationsFirst.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('declarations-first', rule, {
  valid: [fixture('declarations_first', 'first.js')],
  invalid: [
    {
      ...fixture('declarations_first', 'late.js'),
      errors: [
        { messageId: 'late', data: { names: 'LIMIT', first: 'addLimit' }, line: 9 },
        { messageId: 'late', data: { names: 'double', first: 'addLimit' }, line: 12 },
      ],
    },
  ],
});
