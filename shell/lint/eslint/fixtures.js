/**
 * @file Reading the lint fixtures under shell/lint/eslint/fixtures/, beside the rules they belong to, for the rule tests,
 * as the {code, filename} a RuleTester case takes.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * The RuleTester case for the fixture `shell/lint/eslint/fixtures/<group>/<name>`.
 *
 * @param group The fixture directory under shell/lint/eslint/fixtures/.
 * @param name The fixture's file name.
 */
export function fixture(group, name) {
  const path = fileURLToPath(new URL(`./fixtures/${group}/${name}`, import.meta.url));
  return { code: readFileSync(path, 'utf8'), filename: path };
}
