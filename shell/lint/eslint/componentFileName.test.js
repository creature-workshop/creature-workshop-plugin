/**
 * @file house/component-file-name over the fixtures under
 * tests/fixtures/component_file_name/: a file named after its component
 * passes, whichever form the component takes, and a file named otherwise
 * fails on the component.
 */
import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './componentFileName.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing JSX as a module. */
const tester = new RuleTester({
  languageOptions: { ecmaVersion: 2024, sourceType: 'module', parserOptions: { ecmaFeatures: { jsx: true } } },
});

tester.run('component-file-name', rule, {
  valid: [
    fixture('component_file_name', 'Chip.jsx'),
    fixture('component_file_name', 'Row.jsx'),
    fixture('component_file_name', 'store.js'),
  ],
  invalid: [
    { ...fixture('component_file_name', 'Other.jsx'), errors: [{ messageId: 'named', data: { name: 'Chip' }, line: 4 }] },
  ],
});
