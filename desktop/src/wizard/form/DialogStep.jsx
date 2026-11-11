/**
 * @file A dialog step in a form wizard: its message.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * The step's message as a paragraph.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The dialog.
 */
export function DialogStep({ step }) {
  return <p className={cn('workshop-wizard-dialog', 'text-(--ui-text-secondary)')}>{step.text}</p>;
}
