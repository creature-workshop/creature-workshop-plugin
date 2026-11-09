/**
 * @file The ESLint plugin `house`: the ten rules of the house style that
 * no published rule covers. eslint.config.js loads it and turns them on.
 */

import className from './className.js';
import componentFileName from './componentFileName.js';
import declarationsFirst from './declarationsFirst.js';
import fileBlockBlankLine from './fileBlockBlankLine.js';
import namedEffect from './namedEffect.js';
import namedElement from './namedElement.js';
import noBannerComment from './noBannerComment.js';
import noCommentInBody from './noCommentInBody.js';
import noTestId from './noTestId.js';
import tagSpacing from './tagSpacing.js';

/** The plugin: its name and its rules, keyed by the names the config turns on. */
export default {
  meta: { name: 'house' },
  rules: {
    'class-name': className,
    'component-file-name': componentFileName,
    'declarations-first': declarationsFirst,
    'file-block-blank-line': fileBlockBlankLine,
    'named-effect': namedEffect,
    'named-element': namedElement,
    'no-banner-comment': noBannerComment,
    'no-comment-in-body': noCommentInBody,
    'no-test-id': noTestId,
    'tag-spacing': tagSpacing,
  },
};
