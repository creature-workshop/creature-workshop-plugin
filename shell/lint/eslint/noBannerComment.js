/**
 * @file The rule house/no-banner-comment: no comment that draws a line, such
 * as a line comment of dashes around the word Helpers, or a block comment
 * that is only equals signs. A banner marks a part of a file as a separate
 * unit that nothing enforces; the language's way to separate code is a
 * file, so a banner is the sign to split one.
 */

/** A run of three or more of the characters a banner is drawn with. */
const RULE = /[-=─—═_*#]{3,}/;

/**
 * Whether a comment draws a line: a line of it is only banner characters and
 * spaces, or opens or closes with a run of them.
 *
 * @param comment A comment token.
 */
function drawsLine(comment) {
  return comment.value.split('\n').some((line) => {
    const text = line.replace(/^\s*\*?\s*/, '').trim();
    return text.length > 0 && (RULE.test(text.slice(0, 3)) || RULE.test(text.slice(-3)));
  });
}

/** The rule, reporting each comment that draws a line. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'no banner comments; a banner is the sign to split the file' },
    schema: [],
    messages: {
      banner: 'This comment draws a line across the file, which marks a part of it as a separate unit that nothing enforces. Delete the banner and move the part it labels into a file of its own, named for what the banner said.',
    },
  },
  create(context) {
    return {
      Program() {
        for (const comment of context.sourceCode.getAllComments()) {
          if (drawsLine(comment)) {
            context.report({ loc: comment.loc, messageId: 'banner' });
          }
        }
      },
    };
  },
};
