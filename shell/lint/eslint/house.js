/**
 * @file The ESLint plugin `house`: the five rules of the house style that
 * no published rule covers. eslint.config.js loads it and turns them on.
 */
import componentFileName from './componentFileName.js';
import namedElement from './namedElement.js';
import noCommentInBody from './noCommentInBody.js';
import noTestId from './noTestId.js';
import useEffectDoc from './useEffectDoc.js';

/** The plugin: its name and its rules, keyed by the names the config turns on. */
export default {
  meta: { name: 'house' },
  rules: {
    'component-file-name': componentFileName,
    'named-element': namedElement,
    'no-comment-in-body': noCommentInBody,
    'no-test-id': noTestId,
    'use-effect-doc': useEffectDoc,
  },
};
