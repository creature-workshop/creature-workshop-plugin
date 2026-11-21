/**
 * @file The pane's JSX runtime for a development build, which the JSX
 * transform asks for as `<import source>/jsx-dev-runtime`. It wraps a
 * component given a `bind` prop exactly as jsx-runtime.js does.
 */

import { Fragment, jsxDEV as make } from 'react/jsx-dev-runtime';
import { Bound } from './Bound.jsx';
import { wrapped } from './wrap.js';

/** React's Fragment, which the JSX transform imports for `<>...</>`. */
export { Fragment };

/**
 * An element, with the source position React's development build records.
 *
 * @param type The element's type.
 * @param props The element's props.
 * @param {...unknown} rest The key, and where the element is in the source.
 */
export function jsxDEV(type, props, ...rest) {
  return wrapped(Bound, make, type, props, ...rest);
}
