/**
 * @file A select step in a form wizard: Desktop's select over its options,
 * labelled with its question.
 */

import { cn, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@hermes/plugin-sdk';
import { useId } from 'react';
import { StepLabel } from './StepLabel.jsx';

/**
 * The question as a small label, with its help in an (i) and the step's
 * hint on the same line, over a select showing `value`. Picking an option
 * calls `onChange` with its value.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The select.
 * @param {string} props.value The current answer.
 * @param {(value: string) => void} props.onChange Takes the new answer.
 */
export function SelectStep(props) {
  const { step, value, onChange } = props;
  const id = useId();
  return (
    <div className={cn('workshop-wizard-select', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
      <StepLabel step={step} htmlFor={id} />
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger id={id} size="sm" className={cn('workshop-wizard-select-trigger', 'self-start')}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {step.options.map((option) => <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>)}
        </SelectContent>
      </Select>
    </div>
  );
}
