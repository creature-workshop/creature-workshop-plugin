/**
 * @file The (i) icon after a field's name that shows the field's help text.
 */

import { Tip } from '@hermes/plugin-sdk';
import { IconButton } from './IconButton.jsx';

/**
 * An info icon button labelled "About <label>", which shows `hint` in
 * Desktop's tooltip when it is hovered or reached with the keyboard.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} props.hint The help text.
 */
export function InfoTip({ label, hint }) {
  return (
    <Tip label={hint}>
      <IconButton label={`About ${label}`} icon="info" />
    </Tip>
  );
}
