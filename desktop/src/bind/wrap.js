/**
 * @file How the pane's JSX runtime makes an element: a component given a
 * `bind` prop is made inside the wrapper, and every other element is made
 * as React makes it.
 */

/**
 * The element React's `make` makes for `type` and `props`, inside
 * `Wrapper` when `type` is a component and `props` carries `bind`. The
 * wrapper is given the same props, with the component as `bound`. A host
 * element such as `div`, the wrapper itself, and an element without `bind`
 * are made unchanged.
 *
 *     wrapped(Bound, jsx, TextField, {label: 'Name', bind: NAME})
 *       ->  jsx(Bound, {label: 'Name', bind: NAME, bound: TextField})
 *
 * @param Wrapper The component that reads the binding, Bound.
 * @param make React's own jsx, jsxs or jsxDEV.
 * @param type The element's type: a component, or a host element's name.
 * @param props The element's props.
 * @param {...unknown} rest What else the runtime passes `make`, such as the key.
 */
export function wrapped(Wrapper, make, type, props, ...rest) {
  if (typeof type === 'string' || type === Wrapper || props?.bind === undefined) {
    return make(type, props, ...rest);
  }
  return make(Wrapper, { ...props, bound: type }, ...rest);
}
