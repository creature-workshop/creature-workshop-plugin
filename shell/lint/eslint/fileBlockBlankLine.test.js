/**
 * @file house/file-block-blank-line over the fixtures under
 * tests/fixtures/file_block_blank_line/: one blank line after the file block
 * passes, and none or two fails on the block.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './fileBlockBlankLine.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('file-block-blank-line', rule, {
  valid: [fixture('file_block_blank_line', 'spaced.js')],
  invalid: [
    { ...fixture('file_block_blank_line', 'crowded.js'), errors: [{ messageId: 'spacing', data: { count: 0 }, line: 1 }] },
    { ...fixture('file_block_blank_line', 'gapped.js'), errors: [{ messageId: 'spacing', data: { count: 2 }, line: 1 }] },
  ],
});
