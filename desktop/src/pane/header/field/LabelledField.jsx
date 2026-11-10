/**
 * @file A small labelled column in the header: a label with an (i) above
 * the selector or name it labels.
 */

import { cn } from '@hermes/plugin-sdk';
import { InfoTip } from '../../../inspector/InfoTip.jsx';

/**
 * The column is a fixed 40% of the header, whatever its selector holds, so
 * the selectors keep their width as the selection changes; it gives way only
 * when the header is too narrow for both and the state. Inline because
 * Desktop's stylesheet has no class for it.
 */
const FIELD_STYLE = { flex: '0 1 40%', rowGap: '2px' };

/** The label row is one small line; the (i)'s 24px button overhangs it rather than making it taller. */
const LABEL_ROW_STYLE = { height: '0.875rem' };

/** The label's font size, which its (i) matches so it is no bigger than the text. */
const LABEL_SIZE = '0.625rem';

/**
 * `label` in small, slightly spaced capitals in the tertiary color, with
 * an (i) after it whose tooltip is `hint`, over `children`. The label has
 * `id`, so the control below can name itself after it with
 * aria-labelledby.
 *
 * @param props The component's props.
 * @param {string} props.id The label's element id.
 * @param {string} props.label What the label says, such as "Repository".
 * @param {string} props.hint What the control is for, which the (i) shows.
 * @param props.children The selector or name.
 */
export function LabelledField({ id, label, hint, children }) {
  return (
    <div className={cn('workshop-header-field', 'flex', 'min-w-0', 'flex-col')} style={FIELD_STYLE}>
      <span
        className={cn(
          'workshop-header-field-label',
          'flex',
          'items-center',
          'gap-1',
          'text-[0.625rem]',
          'uppercase',
          'tracking-wide',
          'text-(--ui-text-tertiary)',
        )}
        style={LABEL_ROW_STYLE}
      >
        <span id={id} className={cn('workshop-header-field-name')}>{label}</span>
        <InfoTip label={label} hint={hint} size={LABEL_SIZE} />
      </span>
      {children}
    </div>
  );
}
