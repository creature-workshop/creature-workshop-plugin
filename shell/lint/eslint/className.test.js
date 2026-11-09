/**
 * @file house/class-name over the fixtures under shell/lint/eslint/fixtures/class_name/:
 * classNames built with cn, one class to a string, pass; a plain string, an
 * expression other than cn, a string given to cn that holds several classes,
 * and one inside a condition each fail.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './className.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules with JSX. */
const tester = new RuleTester({
  languageOptions: { ecmaVersion: 2024, sourceType: 'module', parserOptions: { ecmaFeatures: { jsx: true } } },
});

tester.run('class-name', rule, {
  valid: [fixture('class_name', 'Clean.jsx')],
  invalid: [
    {
      ...fixture('class_name', 'NotCn.jsx'),
      errors: [
        { messageId: 'notCn', line: 9 },
        { messageId: 'notCn', line: 18 },
      ],
    },
    {
      ...fixture('class_name', 'SeveralClasses.jsx'),
      errors: [
        { messageId: 'oneClass', data: { text: 'flex min-w-0', count: 2 }, line: 11 },
        { messageId: 'oneClass', data: { text: 'border-b border-(--ui-stroke-tertiary)', count: 2 }, line: 12 },
        { messageId: 'oneClass', data: { text: 'px-3 py-1', count: 2 }, line: 22 },
        { messageId: 'oneClass', data: { text: '', count: 0 }, line: 22 },
      ],
    },
  ],
});
