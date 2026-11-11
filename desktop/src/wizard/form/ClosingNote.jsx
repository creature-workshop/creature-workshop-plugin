/**
 * @file A closing note of a form wizard: a dialog after the last question,
 * shown with the form's buttons.
 */

import { cn } from '@hermes/plugin-sdk';

/** The note has no margin of its own: the closing group spaces it from the buttons. */
const NOTE_STYLE = Object.freeze({ margin: 0 });

/**
 * The step's message as a faint paragraph, fainter than a dialog among the
 * questions, since it is read with the buttons under it and not as a step.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The dialog.
 */
export function ClosingNote({ step }) {
  return <p className={cn('workshop-wizard-closing-note', 'text-(--ui-text-tertiary)')} style={NOTE_STYLE}>{step.text}</p>;
}
