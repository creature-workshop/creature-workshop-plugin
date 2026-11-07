/**
 * @file house/use-effect-doc over the fixtures under tests/fixtures/use_effect_doc/:
 * an effect with a JSDoc block above it passes, and one without, or with
 * only a line comment, fails on the call.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './useEffectDoc.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('use-effect-doc', rule, {
  valid: [fixture('use_effect_doc', 'documented.js')],
  invalid: [
    { ...fixture('use_effect_doc', 'undocumented.js'), errors: [{ messageId: 'undocumented', line: 6 }, { messageId: 'undocumented', line: 13 }] },
  ],
});
