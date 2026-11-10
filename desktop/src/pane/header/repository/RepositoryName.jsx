/**
 * @file The single repository's name in a box that looks like a selector
 * that cannot be opened: the selector's outline and fill, and half its
 * inset shadow.
 */

import { cn, Tip } from '@hermes/plugin-sdk';
import { INPUT_FILL, INPUT_INSET, INPUT_STROKE } from '../field/inputChrome.js';

/**
 * As tall as the worktree selector beside it (one 20px line inside its 1px
 * outline), in the selector's outline and fill colors, so the two read as a
 * pair and their labels sit level. Positioned, so the shade can cover it.
 * Inline because Desktop's stylesheet has no class for these.
 */
const BOX_STYLE = { position: 'relative', lineHeight: '1.25rem', borderColor: INPUT_STROKE, background: INPUT_FILL };

/**
 * Desktop's inset shadow at half strength, on a layer over the box: a
 * shadow's color cannot be scaled through its variable, but the layer's
 * opacity can, in every theme. It takes no clicks.
 */
const SHADE_STYLE = { position: 'absolute', inset: 0, borderRadius: 'inherit', boxShadow: INPUT_INSET, opacity: 0.5, pointerEvents: 'none' };

/**
 * `name` in the box, labelled by the element `labelledBy` names, with `root`
 * in a tooltip. It reads as disabled: no caret, no hover, a lighter inset.
 *
 * @param props The component's props.
 * @param {string} props.name The repository's name.
 * @param {string} props.root The repository's path.
 * @param {string} props.labelledBy The id of the label above it.
 */
export function RepositoryName({ name, root, labelledBy }) {
  return (
    <Tip label={root}>
      <span
        aria-labelledby={labelledBy}
        className={cn(
          'workshop-repo-name',
          'block',
          'w-full',
          'truncate',
          'rounded-[2.5px]',
          'border',
          'px-2',
          'text-(--ui-text-secondary)',
        )}
        style={BOX_STYLE}
      >
        {name}
        <span aria-hidden="true" className={cn('workshop-repo-name-shade')} style={SHADE_STYLE} />
      </span>
    </Tip>
  );
}
