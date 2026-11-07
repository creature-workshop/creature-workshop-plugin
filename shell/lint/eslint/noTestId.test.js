/**
 * @file house/no-test-id over the fixtures under tests/fixtures/no_test_id/:
 * a test that reads the page by role passes, and one that plants a
 * data-testid and queries getByTestId fails on both.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './noTestId.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing JSX as a module. */
const tester = new RuleTester({
  languageOptions: { ecmaVersion: 2024, sourceType: 'module', parserOptions: { ecmaFeatures: { jsx: true } } },
});

tester.run('no-test-id', rule, {
  valid: [fixture('no_test_id', 'byRole.ct.jsx')],
  invalid: [
    { ...fixture('no_test_id', 'byTestId.ct.jsx'), errors: [{ messageId: 'attribute', line: 5 }, { messageId: 'query', line: 6 }] },
  ],
});
