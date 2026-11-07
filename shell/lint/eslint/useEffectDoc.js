/**
 * @file The rule house/use-effect-doc: every useEffect call has a JSDoc block
 * directly above it saying what the effect does and when it runs. An effect
 * is a side effect at the boundary of the UI, like a private function with
 * no name, so it is documented the way a function is.
 */
import { effectDoc, isEffectCall } from './effectDoc.js';

/** The rule, reporting each useEffect call without a doc block above its statement. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'every useEffect has a doc block saying what it does and when it runs' },
    schema: [],
    messages: {
      undocumented: 'This useEffect has no doc block above it, and an effect is a side effect with no name of its own. Put a /** ... */ block directly above the call that says what the effect does and when it runs.',
    },
  },
  create(context) {
    return {
      CallExpression(node) {
        if (isEffectCall(node) && effectDoc(context.sourceCode, node) === null) {
          context.report({ node, messageId: 'undocumented' });
        }
      },
    };
  },
};
