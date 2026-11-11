/**
 * @file The plain implementation of the wizard contract: every step at
 * once, as a form in the pane. The blizz port (SHOP-106 to SHOP-108) is the
 * other implementation of the same contract and replaces it later.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { finalAnswers, shownSteps, startingValues } from './shown.js';
import { ShownStep } from './ShownStep.jsx';

/** Space between steps: 8px, twice the 4px between a step's label and its field, so each label reads with its own field. */
const FORM_STYLE = Object.freeze({ gap: '0.5rem' });

/** Space above the buttons, so a tap meant for the last step does not land on Set up. */
const ACTIONS_STYLE = Object.freeze({ marginTop: '1rem' });

/**
 * A form named "Set up <tool>" showing the steps the answers lead to, in
 * order: a dialog as its message, a prompt as a text field starting on its
 * fallback, a select starting on its default option, and a confirm as a
 * switch; each with its help in an (i) and its hint on its label's line.
 * The buttons sit apart from the last step. "Set up <tool>" finishes with
 * the answers of the steps shown; Cancel leaves.
 *
 * @param {import('../implementation.js').WizardProps} props The wizard's props.
 */
export function FormWizard(props) {
  const { tool, steps, onFinish, onCancel } = props;
  const [values, setValues] = useState(() => startingValues(steps));
  const change = (key) => (value) => setValues((before) => ({ ...before, [key]: value }));
  const finish = (event) => {
    event.preventDefault();
    onFinish(finalAnswers(steps, values));
  };

  return (
    <form aria-label={`Set up ${tool}`} onSubmit={finish} className={cn('workshop-form-wizard', 'flex', 'min-w-0', 'flex-col')} style={FORM_STYLE}>
      {shownSteps(steps, values).map((at) => <ShownStep key={at} step={steps[at]} value={values[steps[at].key]} onChange={change(steps[at].key)} />)}
      <span className={cn('workshop-form-wizard-actions', 'flex', 'gap-1')} style={ACTIONS_STYLE}>
        <Button size="xs" type="submit">{`Set up ${tool}`}</Button>
        <Button size="xs" variant="ghost" onClick={onCancel}>Cancel</Button>
      </span>
    </form>
  );
}
