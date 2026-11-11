/**
 * @file Fitting a header label to its row: whether the qualifier before
 * the label's name has room, measured as the row is laid out.
 */

import { useLayoutEffect, useRef, useState } from 'react';
import { qualifierFits } from './labelFit.js';

/**
 * Returns `{row, measure, name, fits}`: refs for the label row, the hidden
 * span that holds the qualifier, and the span that holds the name; and
 * whether the qualifier fits the row beside the name and the (i), which is
 * the row's last child. It is measured before paint and again whenever the
 * row is resized, and it is true until the row has been measured.
 */
export function useQualifierFits() {
  const row = useRef(null);
  const measure = useRef(null);
  const name = useRef(null);
  const [fits, setFits] = useState(true);
  useLayoutEffect(fitToRow({ row, measure, name }, setFits), []);

  return { row, measure, name, fits };
}

/**
 * The effect that reads whether the qualifier fits, before paint and on
 * every resize of the label row, until the row goes away.
 *
 * @layoutEffect
 * @param refs The refs of the row, the qualifier's measuring span and the name.
 * @param setFits Stores whether the qualifier fits.
 */
function fitToRow(refs, setFits) {
  return () => {
    const read = () => setFits(qualifierFits(widthsOf(refs)));
    read();
    const observer = new ResizeObserver(read);
    observer.observe(refs.row.current);
    return () => observer.disconnect();
  };
}

/**
 * The widths the fit is decided from, in pixels: the row's, its (i)'s, the
 * qualifier's and the name's.
 *
 * @param refs The refs of the row, the qualifier's measuring span and the name.
 */
function widthsOf(refs) {
  return {
    row: refs.row.current.clientWidth,
    tip: refs.row.current.lastElementChild.offsetWidth,
    qualifier: refs.measure.current.offsetWidth,
    name: refs.name.current.offsetWidth,
  };
}
