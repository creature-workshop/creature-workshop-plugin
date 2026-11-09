/**
 * @file The rule house/tag-spacing: inside a JSDoc block's tags, `@returns`
 * stands apart and the rest stay together. The line before `@returns` (or
 * `@return`) is blank, exactly once, and no blank line comes between any
 * other two tags. The first tag is jsdoc/tag-lines's to space from the
 * description, so this rule starts at the second.
 */

import { isDocBlock } from './docBlock.js';

/** The tags that take one blank line before them. */
const APART = new Set(['returns', 'return']);

/** The rule, reporting each tag after the first whose blank lines above it are not what its kind takes. */
export default {
  meta: {
    type: 'layout',
    docs: { description: 'one blank line before @returns, none between other tags' },
    schema: [],
    messages: {
      apart: 'Put exactly one blank line before @{{tag}}, so the value a function returns stands apart from its parameters; there are {{blanks}}.',
      together: 'Put no blank line before @{{tag}}: the tags of a doc block stay together, and only @returns stands apart; there are {{blanks}}.',
    },
  },
  create(context) {
    return {
      Program() {
        for (const block of context.sourceCode.getAllComments().filter(isDocBlock)) {
          checkBlock(context, block);
        }
      },
    };
  },
};

/**
 * Reports each tag after the first in a doc block whose blank lines above
 * it are not what its kind takes.
 *
 * @param context The rule's context.
 * @param block A JSDoc comment token.
 */
function checkBlock(context, block) {
  const lines = block.value.split('\n').map(textOf);
  const first = lines.findIndex(isTag);
  for (let index = first + 1; first >= 0 && index < lines.length; index += 1) {
    if (isTag(lines[index])) {
      checkTag(context, block, lines, index);
    }
  }
}

/**
 * Reports the tag on a line of a doc block when the blank lines above it are
 * not one for `@returns` or none for any other tag.
 *
 * @param context The rule's context.
 * @param block The JSDoc comment token.
 * @param lines The block's lines, without their leading star.
 * @param index The index of the tag's line.
 */
function checkTag(context, block, lines, index) {
  const tag = lines[index].match(/^@(\w+)/u)[1];
  const blanks = blanksAbove(lines, index);
  const apart = APART.has(tag);
  if (apart ? blanks !== 1 : blanks !== 0) {
    const line = block.loc.start.line + index;
    context.report({ loc: { start: { line, column: 0 }, end: { line, column: 0 } }, messageId: apart ? 'apart' : 'together', data: { tag, blanks } });
  }
}

/**
 * The number of blank lines directly above a line.
 *
 * @param lines The block's lines, without their leading star.
 * @param index The index of the line.
 */
function blanksAbove(lines, index) {
  let count = 0;
  while (index - count - 1 >= 0 && lines[index - count - 1] === '') {
    count += 1;
  }

  return count;
}

/**
 * A line of a doc block without its indentation and leading star.
 *
 * @param line A raw line of the comment's value.
 */
function textOf(line) {
  return line.replace(/^\s*\*?\s?/u, '').trim();
}

/**
 * Whether a line of a doc block opens a tag.
 *
 * @param text The line, without its leading star.
 */
function isTag(text) {
  return text.startsWith('@');
}
