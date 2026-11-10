/**
 * @file The rule house/max-params: no function takes more than five
 * parameters. A rest parameter counts as one. Past five, the parameters
 * that travel together belong in one options object, or in a rest parameter.
 * ESLint's own max-params says only that there are too many; this one says
 * what to do instead.
 */

/** The most parameters a function takes. */
const MAX_PARAMS = 5;

/**
 * The function's name for the message: its own, the variable it is assigned
 * to, or "This function".
 *
 * @param node A function node.
 */
function nameOf(node) {
  if (node.id) {
    return node.id.name;
  }
  return node.parent?.type === 'VariableDeclarator' && node.parent.id.type === 'Identifier' ? node.parent.id.name : 'This function';
}

/**
 * Reports the function when it takes more than MAX_PARAMS parameters.
 *
 * @param context The rule's context.
 * @param node A function node.
 */
function check(context, node) {
  if (node.params.length > MAX_PARAMS) {
    context.report({ node, messageId: 'tooMany', data: { name: nameOf(node), count: node.params.length, max: MAX_PARAMS } });
  }
}

/** The rule, reporting each function declaration, expression or arrow function past the limit. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'no function takes more than five parameters' },
    schema: [],
    messages: {
      tooMany: '{{name}} takes {{count}} parameters, and a function takes at most {{max}}. Gather the parameters that travel together into one options object, such as `{ kind, root, source }`, or take a rest parameter.',
    },
  },
  create(context) {
    return {
      FunctionDeclaration: (node) => check(context, node),
      FunctionExpression: (node) => check(context, node),
      ArrowFunctionExpression: (node) => check(context, node),
    };
  },
};
