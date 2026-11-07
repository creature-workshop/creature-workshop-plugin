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
 * The innermost of the functions whose body holds the range, or undefined.
 * @param range A [start, end] pair of offsets.
 * @param bodies The functions seen so far, each with its body's range.
 */
function enclosing(range, bodies) {
  const holders = bodies.filter((entry) => entry.range[0] <= range[0] && range[1] <= entry.range[1]);
  return holders.sort((a, b) => b.range[0] - a.range[0])[0];
}

/**
 * What to call a function in a message: its own name, the name it is assigned
 * to, or "an anonymous function".
 * @param node A function node.
 */
function nameOf(node) {
  if (node.id) {
    return node.id.name;
  }

  if (node.parent.type === 'VariableDeclarator' && node.parent.id.type === 'Identifier') {
    return node.parent.id.name;
  }

  return 'an anonymous function';
}

/** The rule, reporting each comment that lies inside a function's block body. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'no comments inside a function body' },
    schema: [],
    messages: {
      inside: 'This comment is inside the body of {{name}}, and a function body carries no comments. Say it in the doc block above {{name}}, or give the step it explains a function of its own and say it there.',
    },
  },
  create(context) {
    const bodies = [];
    const allowed = new Set();
    return {
      ':function'(node) {
        if (node.body.type === 'BlockStatement') {
          bodies.push({ range: node.body.range, name: nameOf(node) });
        }
      },
      CallExpression(node) {
        if (isEffectCall(node)) {
          allowed.add(effectDoc(context.sourceCode, node));
        }
      },
      'Program:exit'() {
        for (const comment of context.sourceCode.getAllComments()) {
          const holder = isDirective(comment) || allowed.has(comment) ? undefined : enclosing(comment.range, bodies);
          if (holder) {
            context.report({ loc: comment.loc, messageId: 'inside', data: { name: holder.name } });
          }
        }
      },
    };
  },
};
