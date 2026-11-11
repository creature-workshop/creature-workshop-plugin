/**
 * @file One step of a form wizard, drawn by the component for its kind.
 */

import { isConfirm } from '../steps.js';
import { ConfirmStep } from './ConfirmStep.jsx';
import { DialogStep } from './DialogStep.jsx';
import { PromptStep } from './PromptStep.jsx';
import { SelectStep } from './SelectStep.jsx';

/** The component that draws each kind of step; a confirm is a select over Yes and No, drawn as a switch. */
const STEP_COMPONENTS = Object.freeze({ dialog: DialogStep, prompt: PromptStep, select: SelectStep, confirm: ConfirmStep });

/**
 * The step, drawn by the component for its kind: a switch for a confirm.
 *
 * @param props The component's props.
 * @param {import('../steps.js').Step} props.step The step.
 * @param {string} props.value Its current answer; unused by a dialog.
 * @param {(value: string) => void} props.onChange Takes a new answer.
 */
export function ShownStep({ step, value, onChange }) {
  const Step = STEP_COMPONENTS[isConfirm(step) ? 'confirm' : step.kind];
  return <Step step={step} value={value} onChange={onChange} />;
}
