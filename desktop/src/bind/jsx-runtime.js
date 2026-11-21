/**
 * @file The JSX runtime of the pane. Every JSX expression under
 * desktop/src compiles to a call of `jsx` or `jsxs` here, because the
 * bundler and the component tests name `@workshop/jsx` as the JSX import
 * source and resolve that name to this folder. The file's name is the one
 * the JSX transform asks for, `<import source>/jsx-runtime`.
 *
 * It is React's runtime with one addition: a component given a `bind` prop
 * is drawn inside Bound, which reads and writes the checkout's synced
 * files for it. A component's author writes no data hook; whoever uses
 * the component names its data with `bind`.
 */

import { Fragment, jsx as make, jsxs as makeStatic } from 'react/jsx-runtime';
import { Bound } from './Bound.jsx';
import { wrapped } from './wrap.js';

/** React's Fragment, which the JSX transform imports for `<>...</>`. */
export { Fragment };

/**
 * An element with children that may change between renders.
 *
 * @param type The element's type.
 * @param props The element's props.
 * @param {string} [key] The element's key.
 */
export function jsx(type, props, key) {
  return wrapped(Bound, make, type, props, key);
}

/**
 * An element whose children are fixed in the source.
 *
 * @param type The element's type.
 * @param props The element's props.
 * @param {string} [key] The element's key.
 */
export function jsxs(type, props, key) {
  return wrapped(Bound, makeStatic, type, props, key);
}
