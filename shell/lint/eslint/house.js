/**
 * @file The ESLint plugin `house`: the two rules of the house style that no
 * published rule covers. eslint.config.js loads it and turns them on.
 */
import componentFileName from './componentFileName.js';
import noCommentInBody from './noCommentInBody.js';

/** The plugin: its name and its rules, keyed by the names the config turns on. */
export default {
  meta: { name: 'house' },
  rules: {
    'component-file-name': componentFileName,
    'no-comment-in-body': noCommentInBody,
  },
};
