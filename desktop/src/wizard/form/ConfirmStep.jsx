/**
 * @file A confirm step in a form wizard: a switch, on for Yes.
 */

import { cn, Switch } from '@hermes/plugin-sdk';
import { useId } from 'react';
import { StepLabel } from './StepLabel.jsx';

/**
 * Desktop's switch, on when `value` is `yes`, with the question and its
 * help in an (i) beside it, and the step's hint at the end of its line. Flipping it calls
 * `onChange` with `yes` or `no`.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The confirm.
 * @param {string} props.value The current answer, `yes` or `no`.
 * @param {(value: string) => void} props.onChange Takes the new answer.
 */
export function ConfirmStep(props) {
  const { step, value, onChange } = props;
  const id = useId();
  return (
    <div className={cn('workshop-wizard-confirm', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
      <span className={cn('workshop-wizard-confirm-row', 'flex', 'items-center', 'gap-2')}>
        <Switch id={id} size="xs" checked={value === 'yes'} onCheckedChange={(on) => onChange(on ? 'yes' : 'no')} />
        <StepLabel step={step} htmlFor={id} />
      </span>
    </div>
  );
}
