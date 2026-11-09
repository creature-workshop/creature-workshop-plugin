/**
 * @file The rule house/named-effect: the effect a component runs is a
 * function defined on its own in the same file, never written inline in the
 * hook call, and its doc block says which hook runs it. A useEffect or
 * useLayoutEffect takes a name (the effect) or a call that returns one (a
 * factory over the component's refs and setters), and the function that
 * name refers to carries `@effect` for useEffect or `@layoutEffect` for
 * useLayoutEffect. jsdoc/require-jsdoc holds the rest of its doc block to
 * the same rules as any other function's.
 */

import { isEffectCall } from './effectCall.js';
import { docBlockOf, tagsOf } from './docBlock.js';

/** The kinds of node that are a function written in place. */
const INLINE = new Set(['ArrowFunctionExpression', 'FunctionExpression']);

/** The tag an effect's doc block carries, by the hook that runs it. */
const TAGS = { useEffect: 'effect', useLayoutEffect: 'layoutEffect' };

/** The rule, reporting each effect hook given an inline function, a function from elsewhere, or one without its hook's tag. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: 'an effect is a function defined in the file, tagged for the hook that runs it' },
    schema: [],
    messages: {
      inline: 'This {{hook}} is given its effect inline. Define the effect as a function of its own in this file, with a doc block that carries @{{tag}} and says what it does and when it runs, and pass it by name, or pass a call of it when it needs the component\'s refs or setters.',
      elsewhere: 'The effect this {{hook}} runs, {{name}}, is not defined in this file. Define it here, with @{{tag}} in its doc block, so the effect is read where it is used.',
      untagged: 'The effect this {{hook}} runs, {{name}}, has no @{{tag}} in its doc block. Add it, so the function reads as an effect where it is defined.',
    },
  },
  create(context) {
    return {
      CallExpression(node) {
        if (isEffectCall(node) && node.arguments.length > 0) {
          check(context, node.callee.name, node.arguments[0]);
        }
      },
    };
  },
};

/**
 * Reports the effect argument of a hook call when it is written inline, is
 * not a function defined in the file, or lacks the hook's tag.
 *
 * @param context The rule's context.
 * @param hook The hook's name, useEffect or useLayoutEffect.
 * @param effect The first argument of the hook call.
 */
function check(context, hook, effect) {
  const tag = TAGS[hook];
  if (INLINE.has(effect.type)) {
    context.report({ node: effect, messageId: 'inline', data: { hook, tag } });
    return;
  }

  const name = nameOf(effect);
  const declaration = name && declarationOf(context.sourceCode, effect, name);
  if (!declaration) {
    context.report({ node: effect, messageId: 'elsewhere', data: { hook, tag, name: name ?? 'it' } });
    return;
  }

  if (!tagsOf(docBlockOf(context.sourceCode, declaration)).has(tag)) {
    context.report({ node: effect, messageId: 'untagged', data: { hook, tag, name } });
  }
}

/**
 * The name the effect argument refers to: the identifier itself, or the
 * function a factory call calls; null for anything else.
 *
 * @param effect The first argument of a hook call.
 */
function nameOf(effect) {
  if (effect.type === 'Identifier') {
    return effect.name;
  }

  if (effect.type === 'CallExpression' && effect.callee.type === 'Identifier') {
    return effect.callee.name;
  }

  return null;
}

/**
 * The function declaration, or the variable holding a function, that the
 * name refers to where the effect is used; null when the name is a
 * parameter, an import, or not declared in the file.
 *
 * @param sourceCode The file's SourceCode.
 * @param node The node the name is used at.
 * @param name The name.
 */
function declarationOf(sourceCode, node, name) {
  const definition = variableNamed(sourceCode.getScope(node), name)?.defs[0];
  if (definition?.type === 'FunctionName') {
    return definition.node;
  }

  if (definition?.type === 'Variable' && INLINE.has(definition.node.init?.type)) {
    return definition.node;
  }

  return null;
}

/**
 * The variable a name resolves to from a scope, searching outwards, or undefined.
 *
 * @param scope The scope the name is used in.
 * @param name The name.
 */
function variableNamed(scope, name) {
  return scope ? (scope.set.get(name) ?? variableNamed(scope.upper, name)) : undefined;
}
