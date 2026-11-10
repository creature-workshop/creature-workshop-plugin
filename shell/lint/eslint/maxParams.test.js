/**
 * @file house/max-params over the fixtures under shell/lint/eslint/fixtures/max_params/:
 * five parameters, an options object and a rest parameter pass, and six
 * parameters, counting a rest parameter, fail.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './maxParams.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing a module. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('max-params', rule, {
  valid: [fixture('max_params', 'few.js')],
  invalid: [
    { ...fixture('max_params', 'many.js'), errors: [{ messageId: 'tooMany', line: 16 }, { messageId: 'tooMany', line: 30 }] },
  ],
});
