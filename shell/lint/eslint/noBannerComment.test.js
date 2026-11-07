/**
 * @file house/no-banner-comment over the fixtures under
 * tests/fixtures/no_banner_comment/: doc blocks, directives and a dash in
 * prose pass, and a comment that draws a line fails, in each of its forms.
 */

import { describe, it } from 'node:test';
import { RuleTester } from 'eslint';
import rule from './noBannerComment.js';
import { fixture } from './fixtures.js';

RuleTester.describe = describe;
RuleTester.it = it;

/** The tester, parsing modules. */
const tester = new RuleTester({ languageOptions: { ecmaVersion: 2024, sourceType: 'module' } });

tester.run('no-banner-comment', rule, {
  valid: [fixture('no_banner_comment', 'plain.js')],
  invalid: [
    {
      ...fixture('no_banner_comment', 'banners.js'),
      errors: [{ messageId: 'banner', line: 3 }, { messageId: 'banner', line: 10 }, { messageId: 'banner', line: 12 }],
    },
  ],
});
