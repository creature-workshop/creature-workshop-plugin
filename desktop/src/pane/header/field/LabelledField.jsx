/**
 * @file A small labelled column in the header: a label with an (i) above
 * the selector or name it labels. The label keeps to one line: when the
 * column is too narrow for all of it, it drops its qualifier.
 */

import { cn } from '@hermes/plugin-sdk';
import { InfoTip } from '../../../inspector/InfoTip.jsx';
import { LABEL_GAP } from './labelFit.js';
import { useQualifierFits } from './useQualifierFits.js';

/**
 * The column is a fixed 40% of the header, whatever its selector holds, so
 * the selectors keep their width as the selection changes; it gives way only
 * when the header is too narrow for both and the state. Inline because
 * Desktop's stylesheet has no class for it.
 */
const FIELD_STYLE = { flex: '0 1 40%', rowGap: '2px' };

/**
 * The label row is one small line that never wraps; the (i)'s 24px button
 * overhangs it rather than making it taller. Its layout is inline style,
 * not utility classes, so the fitting works in any host, including the
 * test page, which has no stylesheet.
 */
const LABEL_ROW_STYLE = { position: 'relative', display: 'flex', alignItems: 'center', gap: `${LABEL_GAP}px`, height: '0.875rem', whiteSpace: 'nowrap' };

/** The measuring span: the qualifier and the space after it, in the label's own type, never seen and never in the way. */
const MEASURE_STYLE = { position: 'absolute', left: 0, top: 0, visibility: 'hidden', whiteSpace: 'pre' };

/** The label's font size, which its (i) matches so it is no bigger than the text. */
const LABEL_SIZE = '0.625rem';

/**
 * `qualifier` and `label`, such as "Session Repository", on one line in
 * small, slightly spaced capitals in the tertiary color, with an (i) after
 * them whose tooltip is `hint`, over `children`. When the column is too
 * narrow for both words beside the (i), the label shows `label` alone. The
 * label has `id`, so the control below can name itself after it with
 * aria-labelledby, and its name is both words whichever it shows.
 *
 * @param props The component's props.
 * @param {string} props.id The label's element id.
 * @param {string} props.qualifier The word before the name, such as "Session", dropped when it does not fit.
 * @param {string} props.label The label's name, such as "Repository".
 * @param {string} props.hint What the control is for, which the (i) shows.
 * @param props.children The selector or name.
 */
export function LabelledField({ id, qualifier, label, hint, children }) {
  const { row, measure, name, fits } = useQualifierFits();
  const whole = `${qualifier} ${label}`;

  return (
    <div className={cn('workshop-header-field', 'flex', 'min-w-0', 'flex-col')} style={FIELD_STYLE}>
      <span
        ref={row}
        className={cn(
          'workshop-header-field-label',
          'text-[0.625rem]',
          'uppercase',
          'tracking-wide',
          'text-(--ui-text-tertiary)',
        )}
        style={LABEL_ROW_STYLE}
      >
        <span id={id} aria-label={whole} className={cn('workshop-header-field-name')}>
          {fits && `${qualifier} `}
          <span ref={name} className={cn('workshop-header-field-short-name')}>{label}</span>
        </span>
        <span ref={measure} aria-hidden="true" className={cn('workshop-header-field-measure')} style={MEASURE_STYLE}>{`${qualifier} `}</span>
        <InfoTip label={whole} hint={hint} size={LABEL_SIZE} />
      </span>
      {children}
    </div>
  );
}
