/**
 * @file The house rules for the JavaScript, which `pnpm run lint` runs over
 * every tracked .js and .jsx file of the project, with one blank line after
 * the file block. ESLint takes the paths
 * here relative to the directory it runs in, which is the project root,
 * because the config is named with --config: ESLint's and React's recommended rules; a
 * JSDoc block at the top of every file and on every top-level declaration,
 * exported or not, each with a description and one for every parameter, the
 * way a shellops doc block lists its args; one React component per file, in
 * a file of the component's name; a doc block on every useEffect; no other
 * comment inside a function body; a class name with the workshop- prefix on
 * every div and span, saying what the box is; and, in the browser tests,
 * Playwright's recommended rules with its locator rules, plus no test ids:
 * a test finds the page by role and by text, as a user does. Two more say
 * when a file should split: its constants come before its first function,
 * and no comment draws a banner across it.
 * The one exception syntax is ESLint's own eslint-disable comment, with the
 * reason after two dashes.
 */

import js from '@eslint/js';
import globals from 'globals';
import jsdoc from 'eslint-plugin-jsdoc';
import playwright from 'eslint-plugin-playwright';
import react from 'eslint-plugin-react';
import house from '../../../shell/lint/eslint/house.js';

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
      '.ops/cache/**',
      '.ops/docs/**',
      '.ops/__compiled__*/**',
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
      'jsdoc/tag-lines': ['error', 'any', { startLines: 1 }],
      'jsdoc/check-tag-names': ['error', { definedTags: ['effect', 'layoutEffect'] }],
      'react/no-multi-comp': ['error', { ignoreStateless: false }],
      'react/prop-types': 'off',
      'house/declarations-first': 'error',
      'house/file-block-blank-line': 'error',
      'house/no-banner-comment': 'error',
      'house/no-comment-in-body': 'error',
      'house/no-test-id': 'error',
      'house/named-effect': 'error',
      'house/tag-spacing': 'error',
    },
  },
  {
    files: ['desktop/src/**/*.{js,jsx}'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['**/*.jsx'],
    rules: { 'house/component-file-name': 'error', 'house/named-element': 'error' },
  },
  {
    ...playwright.configs['flat/recommended'],
    files: ['**/*.ct.jsx'],
  },
  {
    files: ['**/*.ct.jsx'],
    rules: {
      'playwright/no-raw-locators': 'error',
      'playwright/prefer-native-locators': 'error',
      'playwright/prefer-locator': 'error',
    },
  },
];
