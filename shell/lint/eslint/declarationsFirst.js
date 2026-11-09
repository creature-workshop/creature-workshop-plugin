/**
 * @file The rule house/declarations-first: a module's top-level constants
 * come before its first function or class. A constant declared in the middle
 * of a file, next to where it is used, is a sign that the file does more than
 * one job and should split, the same sign as a banner comment.
 */

/**
 * Whether the top-level statement declares a function or a class, inside or
 * outside an export.
 *
 * @param statement A top-level statement.
 */
function declaresCode(statement) {
  const node = statement.declaration || statement;
  return node.type === 'FunctionDeclaration' || node.type === 'ClassDeclaration';
}

/**
 * The VariableDeclaration a top-level statement is, or wraps in an export, or undefined.
 *
 * @param statement A top-level statement.
 */
function variableOf(statement) {
  const node = statement.declaration || statement;
  return node.type === 'VariableDeclaration' ? node : undefined;
}

/**
 * The names a variable declaration declares, joined for a message.
 *
 * @param declaration A VariableDeclaration.
 */
function namesOf(declaration) {
  return declaration.declarations.map((item) => (item.id.type === 'Identifier' ? item.id.name : '...')).join(', ');
}

/** The rule, reporting each top-level variable declared after the first function or class. */
export default {
  meta: {
    type: 'suggestion',
    docs: { description: "a module's constants come before its first function or class" },
    schema: [],
    messages: {
      late: '{{names}} is declared after the first function of this file, and a file declares its constants before its functions. Move it above {{first}}, or, if it belongs with the functions around it, give those their own file.',
    },
  },
  create(context) {
    return {
      Program(program) {
        let first;
        for (const statement of program.body) {
          const variable = variableOf(statement);
          if (first === undefined && declaresCode(statement)) {
            first = (statement.declaration || statement).id.name;
          } else if (first !== undefined && variable) {
            context.report({ node: variable, messageId: 'late', data: { names: namesOf(variable), first } });
          }
        }
      },
    };
  },
};
