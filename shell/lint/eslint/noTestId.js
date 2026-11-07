/**
 * @file The rule house/no-test-id: a test finds the page the way a user
 * does, by role and by text, never by a hook planted for it. A data-testid
 * attribute on an element and a getByTestId call are both reported.
 */

/**
 * Whether the JSX attribute is a data-testid.
 * @param attribute A JSXAttribute.
 */
function isTestIdAttribute(attribute) {
  return attribute.name.type === 'JSXIdentifier' && attribute.name.name === 'data-testid';
}

/**
 * Whether the call is a getByTestId.
 * @param call A CallExpression.
 */
function isTestIdQuery(call) {
  return call.callee.type === 'MemberExpression' && call.callee.property.type === 'Identifier' && call.callee.property.name === 'getByTestId';
}

/** The rule, reporting each data-testid attribute and each getByTestId call. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'no test ids: find the page by role and by text, as a user does' },
    schema: [],
    messages: {
      attribute: 'This data-testid plants a hook for the tests that a user never sees. Remove it, and let the test find the element by its role or its text; give it a role if it has none.',
      query: 'This getByTestId finds the element by a hook a user never sees. Use getByRole or getByText, the way a user finds it.',
    },
  },
  create(context) {
    return {
      JSXAttribute(attribute) {
        if (isTestIdAttribute(attribute)) {
          context.report({ node: attribute, messageId: 'attribute' });
        }
      },
      CallExpression(call) {
        if (isTestIdQuery(call)) {
          context.report({ node: call, messageId: 'query' });
        }
      },
    };
  },
};
