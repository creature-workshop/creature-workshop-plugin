/**
 * @file The (i) icon after a field's name that shows the field's help text,
 * and its error form, which says why something failed.
 */

import { Tip } from '@hermes/plugin-sdk';
import { IconButton } from './IconButton.jsx';

/**
 * An icon button labelled "About <label>", which shows `hint` in Desktop's
 * tooltip when it is hovered or reached with the keyboard. It is an (i) in
 * the field's colors, or, when `error` is set, Desktop's error glyph in the
 * destructive color, the one Desktop uses wherever it reports an error.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} props.hint The help text, or why something failed.
 * @param {boolean} [props.error] Whether the hint says why something failed.
 */
export function InfoTip({ label, hint, error = false }) {
  return (
    <Tip label={hint}>
      <IconButton label={`About ${label}`} icon={error ? 'error' : 'info'} error={error} />
    </Tip>
  );
}
