/**
 * @file The rule house/class-name: every className is a call of the SDK's
 * `cn`, and every string given to `cn` holds exactly one class. A class list
 * built that way reads as one class to a line, a diff that adds or drops a
 * class changes one line, and `cn` merges classes that set the same property.
 * A string inside a condition given to `cn`, such as `open && 'flex'`, is
 * held to the same rule.
 */

/** The name of the function every className calls. */
const CN = 'cn';

/** The rule, reporting a className that is not a cn call, and a string given to cn that holds no class or several. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'a className is a cn call, with one class in each string given to it' },
    schema: [],
    messages: {
      notCn: 'Build this className with cn from @hermes/plugin-sdk, one class to an argument, so every class list in the pane reads the same way and conflicting classes merge.',
      oneClass: 'Give cn one class in each string: "{{text}}" holds {{count}}. Put each class in an argument of its own.',
    },
  },
  create(context) {
    return {
      JSXAttribute(node) {
        if (node.name.name === 'className' && !isCnCall(expressionOf(node.value))) {
          context.report({ node, messageId: 'notCn' });
        }
      },
      CallExpression(node) {
        if (isCnCall(node)) {
          node.arguments.forEach((argument) => checkArgument(context, argument));
        }
      },
    };
  },
};

/**
 * The expression a JSX attribute's value holds: the expression in braces,
 * or the string itself for a plain string value.
 *
 * @param value The attribute's value node.
 */
function expressionOf(value) {
  return value?.type === 'JSXExpressionContainer' ? value.expression : value;
}

/**
 * Whether a node is a call of cn.
 *
 * @param node The node, or null.
 */
function isCnCall(node) {
  return node?.type === 'CallExpression' && node.callee.type === 'Identifier' && node.callee.name === CN;
}

/**
 * Reports each string in one argument of cn that holds no class or several:
 * the argument itself, or the strings a condition in it can give.
 *
 * @param context The rule's context.
 * @param argument The argument.
 */
function checkArgument(context, argument) {
  stringsIn(argument).forEach((string) => checkString(context, string));
}

/**
 * The string nodes an argument of cn can give: itself when it is a string or
 * a template, the right side of `&&` or `||`, and both branches of `? :`.
 *
 * @param node The argument, or a part of it.
 */
function stringsIn(node) {
  if (node.type === 'LogicalExpression') {
    return stringsIn(node.right);
  }

  if (node.type === 'ConditionalExpression') {
    return [...stringsIn(node.consequent), ...stringsIn(node.alternate)];
  }

  return isString(node) ? [node] : [];
}

/**
 * Whether a node is a string literal or a template literal.
 *
 * @param node The node.
 */
function isString(node) {
  return (node.type === 'Literal' && typeof node.value === 'string') || node.type === 'TemplateLiteral';
}

/**
 * Reports a string that holds no class or more than one.
 *
 * @param context The rule's context.
 * @param node The string node.
 */
function checkString(context, node) {
  const text = textOf(context.sourceCode, node);
  const count = text.split(/\s+/).filter(Boolean).length;
  if (count !== 1) {
    context.report({ node, messageId: 'oneClass', data: { text: text.trim(), count } });
  }
}

/**
 * The text a string node holds: a literal's value, or a template's source
 * between its backticks.
 *
 * @param sourceCode The file's SourceCode.
 * @param node The string node.
 */
function textOf(sourceCode, node) {
  return node.type === 'Literal' ? node.value : sourceCode.getText(node).slice(1, -1);
}
