/**
 * @file The small icon button every inspector icon uses, so each one has
 * the same size, padding and keyboard behaviour.
 */

import { Button, Codicon } from '@hermes/plugin-sdk';

/**
 * Paints the button's hover background on its content box only: 2px inside
 * the 24px button on every side. The whole button still takes the click,
 * the background stops short of the line under the field's name, and
 * Desktop's focus ring has room around the icon. Inline, because Desktop's
 * stylesheet has no class for background-clip.
 */
const INSET_HOVER = Object.freeze({ backgroundClip: 'content-box', padding: '2px' });

/**
 * A 24px ghost button holding a 0.75rem codicon, the size of Desktop's own
 * disclosure carets, labelled `label` for assistive technology, with its
 * hover background inset 2px and Desktop's focus ring. Any other props,
 * such as those a tooltip's trigger adds, go to the button.
 *
 * @param props The component's props.
 * @param {string} props.label What the button does, for assistive technology.
 * @param {string} props.icon The codicon's name, such as `edit` or `info`.
 */
export function IconButton({ label, icon, ...rest }) {
  return (
    <Button variant="ghost" size="icon-xs" aria-label={label} style={INSET_HOVER} {...rest}>
      <Codicon name={icon} size="0.75rem" />
    </Button>
  );
}
