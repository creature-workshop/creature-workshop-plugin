/**
 * @file The rule house/file-block-blank-line: exactly one blank line between
 * the file's doc block and whatever comes next, so the block reads as the
 * file's own and not as the doc of the first import.
 */

/**
 * The file's doc block: the first comment, when it is a JSDoc block that
 * names the file tag.
 *
 * @param sourceCode The file's SourceCode.
 */
function fileBlock(sourceCode) {
  const first = sourceCode.getAllComments()[0];
  return first && first.type === 'Block' && first.value.startsWith('*') && /@file\b/.test(first.value) ? first : undefined;
}

/**
 * How many blank lines separate the block from the next token or comment, or
 * undefined when nothing follows it.
 *
 * @param sourceCode The file's SourceCode.
 * @param block The file's doc block.
 */
function blankLinesAfter(sourceCode, block) {
  const next = sourceCode.getTokenAfter(block, { includeComments: true });
  return next ? next.loc.start.line - block.loc.end.line - 1 : undefined;
}

/** The rule, reporting a file block followed by no blank line or by more than one. */
export default {
  meta: {
    type: 'layout',
    docs: { description: 'exactly one blank line after the file doc block' },
    schema: [],
    messages: {
      spacing: 'The file doc block is followed by {{count}} blank lines, and exactly one separates it from what comes next. Leave one empty line after the closing */.',
    },
  },
  create(context) {
    return {
      Program() {
        const block = fileBlock(context.sourceCode);
        const count = block ? blankLinesAfter(context.sourceCode, block) : undefined;
        if (count !== undefined && count !== 1) {
          context.report({ loc: block.loc, messageId: 'spacing', data: { count } });
        }
      },
    };
  },
};
