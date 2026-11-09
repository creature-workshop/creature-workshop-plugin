/**
 * @file Recognising a call of an effect hook, for house/named-effect.
 */

/** The hooks that run an effect. */
const EFFECT_HOOKS = new Set(['useEffect', 'useLayoutEffect']);

/**
 * Whether the node is a call of useEffect or useLayoutEffect.
 *
 * @param node Any AST node.
 */
export function isEffectCall(node) {
  return node.type === 'CallExpression' && node.callee.type === 'Identifier' && EFFECT_HOOKS.has(node.callee.name);
}
