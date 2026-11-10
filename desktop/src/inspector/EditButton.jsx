/**
 * @file The pencil button that opens a inspector field's editor.
 */

import { Button, Codicon } from '@hermes/plugin-sdk';

/**
 * Paints the button's hover background on its content box only: 2px inside
 * the 24px button on every side. The whole button still takes the click,
 * and the background stops short of the line under the field's name. Inline,
 * because Desktop's stylesheet has no class for background-clip.
 */
const INSET_HOVER = { backgroundClip: 'content-box', padding: '2px' };

/**
 * A small ghost button with a 0.75rem pencil icon, the size of Desktop's
 * own disclosure carets, labelled "Edit <label>". Its hover background is
 * 20px inside a 24px click target.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {() => void} props.onClick Opens the editor.
 */
export function EditButton({ label, onClick }) {
  return (
    <Button variant="ghost" size="icon-xs" aria-label={`Edit ${label}`} onClick={onClick} style={INSET_HOVER}>
      <Codicon name="edit" size="0.75rem" />
    </Button>
  );
}
