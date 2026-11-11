/**
 * @file A step's label row in a form wizard: its question, an (i) when it
 * has help, and its hint at the far end.
 */

import { cn } from '@hermes/plugin-sdk';
import { InfoTip } from '../../inspector/InfoTip.jsx';

/**
 * The label row is exactly as tall as its text: line height 1, so the
 * pane's line spacing adds nothing above or below the label, and the
 * (i)'s 24px button overhangs the row rather than making it taller. The
 * space under the label is then the step's own 4px.
 */
const ROW_STYLE = Object.freeze({ height: '1lh', lineHeight: 1 });

/**
 * The question as a small tertiary label for the control with id
 * `htmlFor`, then the step's help in an (i), as the pane's fields have it,
 * and the step's hint, such as "Model suggestion", at the right end of the
 * same line.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The step.
 * @param {string} props.htmlFor The id of the control the label names.
 */
export function StepLabel({ step, htmlFor }) {
  return (
    <span className={cn('workshop-wizard-label-row', 'flex', 'min-w-0', 'flex-1', 'items-center', 'gap-1')} style={ROW_STYLE}>
      <label htmlFor={htmlFor} className={cn('workshop-wizard-label', 'text-(--ui-text-tertiary)')}>{step.text}</label>
      {step.info && <InfoTip label={step.text} hint={step.info} />}
      {step.hint && <span className={cn('workshop-wizard-hint', 'ml-auto', 'text-[0.6875rem]', 'text-(--ui-text-tertiary)')}>{step.hint}</span>}
    </span>
  );
}
