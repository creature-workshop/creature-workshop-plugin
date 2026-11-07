/**
 * @file house/named-element over the fixtures under tests/fixtures/named_element/:
 * a div or span with a workshop- class or a role passes, as does any other
 * element, and one with neither fails on its opening tag.
 */
import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './namedElement.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing JSX as a module. */
const tester = new RuleTester({
  languageOptions: { ecmaVersion: 2024, sourceType: 'module', parserOptions: { ecmaFeatures: { jsx: true } } },
});

tester.run('named-element', rule, {
  valid: [fixture('named_element', 'Named.jsx')],
  invalid: [
    {
      ...fixture('named_element', 'Unnamed.jsx'),
      errors: [
        { messageId: 'unnamed', data: { tag: 'div', example: 'unnamed' }, line: 6 },
        { messageId: 'unnamed', data: { tag: 'div', example: 'unnamed' }, line: 7 },
        { messageId: 'unnamed', data: { tag: 'span', example: 'unnamed' }, line: 8 },
      ],
    },
  ],
});
