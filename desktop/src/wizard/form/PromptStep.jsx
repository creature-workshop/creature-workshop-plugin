/**
 * @file A prompt step in a form wizard: a text field labelled with its question.
 */

import { cn, Input } from '@hermes/plugin-sdk';
import { useId } from 'react';
import { StepLabel } from './StepLabel.jsx';

/**
 * The question as a small label, with its help in an (i), over a text
 * field holding `value`, with the step's hint on the label's line. Typing calls
 * `onChange` with the text.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The prompt.
 * @param {string} props.value The current answer.
 * @param {(value: string) => void} props.onChange Takes the new answer.
 */
export function PromptStep(props) {
  const { step, value, onChange } = props;
  const id = useId();
  return (
    <div className={cn('workshop-wizard-prompt', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
      <StepLabel step={step} htmlFor={id} />
      <Input id={id} size="sm" value={value} onChange={(event) => onChange(event.target.value)} />
    </div>
  );
}
