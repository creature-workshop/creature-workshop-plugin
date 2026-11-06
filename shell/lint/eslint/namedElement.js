/**
 * @file The rule house/named-element: a div or a span says what it is. Both
 * are generic boxes, so each carries a class name with the `workshop-`
 * prefix beside any utility classes, naming the part of the UI it is, the
 * way an element with a role or a semantic tag already does. An element
 * with a role attribute is exempt, since the role names it.
 */

/** The prefix a naming class starts with. */
const PREFIX = 'workshop-';

/**
 * Whether the JSX element is a div or a span.
 * @param opening A JSXOpeningElement.
 */
function isGenericBox(opening) {
  return opening.name.type === 'JSXIdentifier' && (opening.name.name === 'div' || opening.name.name === 'span');
}

/**
 * The attribute of the opening element with the name, or undefined.
 * @param opening A JSXOpeningElement.
 * @param name The attribute's name.
 */
function attribute(opening, name) {
  return opening.attributes.find((item) => item.type === 'JSXAttribute' && item.name.name === name);
}

/**
 * Whether the className attribute names the element: a literal with a
 * `workshop-` token, or an expression whose source mentions the prefix.
 * @param className The className JSXAttribute.
 * @param sourceCode The file's SourceCode.
 */
function names(className, sourceCode) {
  if (className.value.type === 'Literal') {
    return String(className.value.value).split(/\s+/).some((token) => token.startsWith(PREFIX));
  }

  return sourceCode.getText(className.value).includes(PREFIX);
}

/** The rule, reporting each div or span without a role and without a naming class. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'a div or a span carries a class that says what it is' },
    schema: [],
    messages: { unnamed: 'a {{tag}} says what it is: a class name with the workshop- prefix, or a role' },
  },
  create(context) {
    return {
      JSXOpeningElement(opening) {
        if (!isGenericBox(opening) || attribute(opening, 'role')) {
          return;
        }

        const className = attribute(opening, 'className');
        if (!className || !names(className, context.sourceCode)) {
          context.report({ node: opening, messageId: 'unnamed', data: { tag: opening.name.name } });
        }
      },
    };
  },
};
