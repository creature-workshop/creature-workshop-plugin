/**
 * @file Finding the doc block of a useEffect call, for the two rules that
 * care about it: house/use-effect-doc requires one, and
 * house/no-comment-in-body allows it inside the component's body.
 */

/**
 * Whether the node is a call of useEffect.
 * @param node Any AST node.
 */
export function isEffectCall(node) {
  return node.type === 'CallExpression' && node.callee.type === 'Identifier' && node.callee.name === 'useEffect';
}

/**
 * Whether the comment is a JSDoc block.
 * @param comment A comment token.
 */
function isDocBlock(comment) {
  return comment.type === 'Block' && comment.value.startsWith('*');
}

/**
 * The JSDoc block directly before the statement that makes the effect call, or null.
 * @param sourceCode The file's SourceCode.
 * @param call The useEffect call.
 */
export function effectDoc(sourceCode, call) {
  const comments = sourceCode.getCommentsBefore(call.parent).filter(isDocBlock);
  return comments.length === 0 ? null : comments[comments.length - 1];
}
