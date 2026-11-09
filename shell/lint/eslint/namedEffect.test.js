/**
 * @file house/named-effect over the fixtures under shell/lint/eslint/fixtures/named_effect/:
 * an effect passed by name or made by a factory call, defined in the file and
 * tagged for its hook, passes; an inline function, a function without its
 * hook's tag, and a name the file does not define each fail on the argument.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './namedEffect.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('named-effect', rule, {
  valid: [fixture('named_effect', 'tagged.js')],
  invalid: [
    {
      ...fixture('named_effect', 'inline.js'),
      errors: [
        { messageId: 'inline', data: { hook: 'useEffect', tag: 'effect' }, line: 6 },
        { messageId: 'inline', data: { hook: 'useLayoutEffect', tag: 'layoutEffect' }, line: 13 },
      ],
    },
    {
      ...fixture('named_effect', 'untagged.js'),
      errors: [
        { messageId: 'untagged', data: { hook: 'useEffect', tag: 'effect', name: 'subscribeTo' }, line: 8 },
        { messageId: 'untagged', data: { hook: 'useLayoutEffect', tag: 'layoutEffect', name: 'measure' }, line: 15 },
        { messageId: 'elsewhere', data: { hook: 'useEffect', tag: 'effect', name: 'logMount' }, line: 21 },
      ],
    },
  ],
});
