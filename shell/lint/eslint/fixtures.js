/**
 * @file Reading the lint fixtures under tests/fixtures/ for the rule tests,
 * as the {code, filename} a RuleTester case takes.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * The RuleTester case for the fixture `tests/fixtures/<group>/<name>`.
 *
 * @param group The fixture directory under tests/fixtures/.
 * @param name The fixture's file name.
 */
export function fixture(group, name) {
  const path = fileURLToPath(new URL(`../../../tests/fixtures/${group}/${name}`, import.meta.url));
  return { code: readFileSync(path, 'utf8'), filename: path };
}
