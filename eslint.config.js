/**
 * @file The house rules for the JavaScript, which `pnpm run lint` runs over
 * every tracked .js and .jsx file: ESLint's and React's recommended rules; a
 * JSDoc block at the top of every file and on every top-level declaration,
 * exported or not, each with a description and one for every parameter, the
 * way a shellops doc block lists its args; one React component per file, in
 * a file of the component's name; a doc block on every useEffect; and no
 * other comment inside a function body.
 * The one exception syntax is ESLint's own eslint-disable comment, with the
 * reason after two dashes.
 */
import js from '@eslint/js';
import globals from 'globals';
import jsdoc from 'eslint-plugin-jsdoc';
import react from 'eslint-plugin-react';
import house from './shell/lint/eslint/house.js';

/** The selectors of the declarations a file makes at its top level, inside or outside an export. */
const TOP_LEVEL_DECLARATIONS = [
  'Program > FunctionDeclaration',
  'Program > ClassDeclaration',
  'Program > VariableDeclaration',
  'Program > ExportNamedDeclaration',
  'Program > ExportDefaultDeclaration',
];

/** The configuration, as ESLint's flat config: the ignores first, then the rulesets, then the house's own rules. */
export default [
  {
    ignores: [
      'desktop/plugin.js',
      'tests/fixtures/**',
      'shell/.ops/**',
      '.ops/**',
      'playwright/.cache/**',
      'test-results/**',
      'playwright-report/**',
    ],
  },
  js.configs.recommended,
  jsdoc.configs['flat/recommended-error'],
  react.configs.flat.recommended,
  react.configs.flat['jsx-runtime'],
  {
    files: ['**/*.{js,jsx}'],
    plugins: { house },
    languageOptions: { ecmaVersion: 2024, sourceType: 'module', globals: globals.node },
    settings: { react: { version: '19.3' } },
    rules: {
      'jsdoc/require-jsdoc': ['error', { require: { FunctionDeclaration: false }, contexts: TOP_LEVEL_DECLARATIONS }],
      'jsdoc/require-description': ['error', { descriptionStyle: 'any' }],
      'jsdoc/require-file-overview': 'error',
      'jsdoc/require-param-type': 'off',
      'jsdoc/require-returns': 'off',
      'jsdoc/require-returns-type': 'off',
      'react/no-multi-comp': ['error', { ignoreStateless: false }],
      'react/prop-types': 'off',
      'house/no-comment-in-body': 'error',
      'house/use-effect-doc': 'error',
    },
  },
  {
    files: ['desktop/src/**/*.{js,jsx}'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['**/*.jsx'],
    rules: { 'house/component-file-name': 'error' },
  },
];
