/**
 * @file The rule house/component-file-name: a file that declares a React
 * component at its top level is named after the component, `<Name>.jsx`. A
 * component is a function declaration or an arrow function assigned to a
 * const whose name starts with a capital letter. react/no-multi-comp keeps a
 * file to one component; this rule matches the file's name to it.
 */
import { basename, extname } from 'node:path';

/**
 * Whether the name is a component's: it starts with a capital letter.
 * @param name The declared name.
 */
function isComponentName(name) {
  return /^[A-Z]/.test(name);
}

/**
 * The statement itself, or the declaration an export statement wraps.
 * @param statement A top-level statement of the program.
 */
function unwrapExport(statement) {
  return statement.declaration ? statement.declaration : statement;
}

/**
 * Whether the declarator assigns a function to a name.
 * @param declarator One declarator of a variable declaration.
 */
function declaresFunction(declarator) {
  const kind = declarator.init ? declarator.init.type : '';
  return kind === 'ArrowFunctionExpression' || kind === 'FunctionExpression';
}

/**
 * The [{name, node}] of the components one top-level statement declares.
 * @param statement A top-level statement of the program.
 */
function componentsOf(statement) {
  const declaration = unwrapExport(statement);
  if (declaration.type === 'FunctionDeclaration' && declaration.id && isComponentName(declaration.id.name)) {
    return [{ name: declaration.id.name, node: declaration }];
  }

  if (declaration.type !== 'VariableDeclaration') {
    return [];
  }

  return declaration.declarations
    .filter((declarator) => declarator.id.type === 'Identifier' && declaresFunction(declarator))
    .filter((declarator) => isComponentName(declarator.id.name))
    .map((declarator) => ({ name: declarator.id.name, node: declarator }));
}

/**
 * The [{name, node}] of every component the program declares at its top level.
 * @param program The Program node.
 */
function declaredComponents(program) {
  return program.body.flatMap(componentsOf);
}

/** The rule, reporting each component whose name is not the file's stem. */
export default {
  meta: {
    type: 'problem',
    docs: { description: "a component's file is named after the component" },
    schema: [],
    messages: {
      named: '{{file}} declares the component {{name}}, and a file is named after the one component it declares. Rename this file to {{name}}.jsx, or move {{name}} into a file of that name.',
    },
  },
  create(context) {
    const file = basename(context.filename);
    const stem = basename(context.filename, extname(context.filename));
    return {
      Program(program) {
        for (const component of declaredComponents(program)) {
          if (component.name !== stem) {
            context.report({ node: component.node, messageId: 'named', data: { file, name: component.name } });
          }
        }
      },
    };
  },
};
