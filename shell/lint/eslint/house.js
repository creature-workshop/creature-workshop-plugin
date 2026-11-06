/**
 * @file The ESLint plugin `house`: the four rules of the house style that
 * no published rule covers. eslint.config.js loads it and turns them on.
 */
import componentFileName from './componentFileName.js';
import namedElement from './namedElement.js';
import noCommentInBody from './noCommentInBody.js';
import useEffectDoc from './useEffectDoc.js';

/** The plugin: its name and its rules, keyed by the names the config turns on. */
export default {
  meta: { name: 'house' },
  rules: {
    'component-file-name': componentFileName,
    'named-element': namedElement,
    'no-comment-in-body': noCommentInBody,
    'use-effect-doc': useEffectDoc,
  },
};
