/**
 * @file The rule house/no-comment-in-body: no comment inside a function body.
 * A step that needs explaining is its own function, with the explanation in
 * its JSDoc block. Two comments are allowed: an ESLint directive such as
 * eslint-disable-next-line, which is the exception syntax and not a comment
 * about the code, and the doc block of a useEffect, which
 * house/use-effect-doc requires.
 */
import { effectDoc, isEffectCall } from './effectDoc.js';

/**
 * Whether the comment is an ESLint directive.
 * @param comment A comment token.
 */
function isDirective(comment) {
  return /^\s*eslint\b/.test(comment.value);
}

/**
 * Whether the range lies inside one of the ranges.
 * @param range A [start, end] pair of offsets.
 * @param ranges The [start, end] pairs to look in.
 */
function insideAny(range, ranges) {
  return ranges.some((outer) => outer[0] <= range[0] && range[1] <= outer[1]);
}

/** The rule, reporting each comment that lies inside a function's block body. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'no comments inside a function body' },
    schema: [],
    messages: { inside: 'no comments inside a function body; a step that needs one is its own function' },
  },
  create(context) {
    const bodies = [];
    const allowed = new Set();
    return {
      ':function'(node) {
        if (node.body.type === 'BlockStatement') {
          bodies.push(node.body.range);
        }
      },
      CallExpression(node) {
        if (isEffectCall(node)) {
          allowed.add(effectDoc(context.sourceCode, node));
        }
      },
      'Program:exit'() {
        for (const comment of context.sourceCode.getAllComments()) {
          if (!isDirective(comment) && !allowed.has(comment) && insideAny(comment.range, bodies)) {
            context.report({ loc: comment.loc, messageId: 'inside' });
          }
        }
      },
    };
  },
};
