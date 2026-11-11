/**
 * @file Whether a header label has room for its qualifier, the word before
 * its name, such as the "Session" of "Session Repository".
 */

/** The space between a label and its (i), in pixels: the label row's gap. */
export const LABEL_GAP = 4;

/**
 * Whether the label row has room for the qualifier and the name on one
 * line, beside the (i).
 *
 *     qualifierFits({ row: 120, tip: 24, qualifier: 50, name: 60 })  ->  false
 *
 * @param {{row: number, tip: number, qualifier: number, name: number}} widths
 *   The widths, in pixels, of the label row, its (i), the qualifier with the space after it, and the name.
 *
 * @returns {boolean} Whether the qualifier is shown.
 */
export function qualifierFits(widths) {
  return widths.qualifier + widths.name + LABEL_GAP + widths.tip <= widths.row;
}
