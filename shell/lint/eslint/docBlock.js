/**
 * @file Reading a declaration's JSDoc block, for the house rules that look
 * at what a block says: the block itself, and the names of its tags.
 */

/** The kinds of node that wrap a declaration whose doc block sits above the wrapper. */
const WRAPPERS = new Set(['ExportNamedDeclaration', 'ExportDefaultDeclaration', 'VariableDeclaration']);

/**
 * The JSDoc block directly above a declaration, or above the export or
 * variable statement that holds it, or null.
 *
 * @param sourceCode The file's SourceCode.
 * @param node The declaration.
 */
export function docBlockOf(sourceCode, node) {
  const holder = outermost(node);
  return sourceCode.getCommentsBefore(holder).filter(isDocBlock).pop() ?? null;
}

/**
 * The names of the tags in a doc block, without their @; empty for null.
 *
 * @param block A JSDoc comment token, or null.
 */
export function tagsOf(block) {
  return new Set(block ? [...block.value.matchAll(/^\s*\*?\s*@(\w+)/gmu)].map((match) => match[1]) : []);
}

/**
 * Whether the comment is a JSDoc block.
 *
 * @param comment A comment token.
 */
export function isDocBlock(comment) {
  return comment.type === 'Block' && comment.value.startsWith('*');
}

/**
 * The node a declaration's doc block sits above: the declaration, or the
 * statements that wrap it.
 *
 * @param node The declaration.
 */
function outermost(node) {
  return WRAPPERS.has(node.parent.type) ? outermost(node.parent) : node;
}
