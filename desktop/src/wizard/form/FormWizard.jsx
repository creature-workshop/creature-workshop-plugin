/**
 * @file The plain implementation of the wizard contract: every step at
 * once, as a form in the pane. The blizz port (SHOP-106 to SHOP-108) is the
 * other implementation of the same contract and replaces it later.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { ClosingNote } from './ClosingNote.jsx';
import { closingSplit, finalAnswers, shownSteps, startingValues } from './shown.js';
import { ShownStep } from './ShownStep.jsx';

/** Space between steps: 8px, twice the 4px between a step's label and its field, so each label reads with its own field. */
const FORM_STYLE = Object.freeze({ gap: '0.5rem' });

/**
 * The closing group, the closing notes over the buttons: 16px below the
 * last step, so a tap meant for that step does not land on Confirm, and
 * 8px between a note and the buttons, so the note reads with them.
 */
const CLOSING_STYLE = Object.freeze({ display: 'flex', flexDirection: 'column', marginTop: '1rem', gap: '0.5rem' });

/** Confirm is at least 96px wide, wider than its word, so it draws the eye before Cancel. */
const CONFIRM_STYLE = Object.freeze({ minWidth: '6rem' });

/**
 * A form named "Set up <tool>" showing the steps the answers lead to, in
 * order: a dialog as its message, a prompt as a text field starting on its
 * fallback, a select starting on its default option, and a confirm as a
 * switch; each with its help in an (i) and its hint on its label's line.
 * The dialogs after the last question are the form's closing notes: they
 * are faint and sit just above the buttons, and the group sits apart from
 * the last step. Confirm, the wider button, finishes with the answers of
 * the steps shown; Cancel leaves.
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

  const { body, closing } = closingSplit(steps, shownSteps(steps, values));

  return (
    <form aria-label={`Set up ${tool}`} onSubmit={finish} className={cn('workshop-form-wizard', 'flex', 'min-w-0', 'flex-col')} style={FORM_STYLE}>
      {body.map((at) => <ShownStep key={at} step={steps[at]} value={values[steps[at].key]} onChange={change(steps[at].key)} />)}
      <div className={cn('workshop-form-wizard-closing', 'min-w-0')} style={CLOSING_STYLE}>
        {closing.map((at) => <ClosingNote key={at} step={steps[at]} />)}
        <span className={cn('workshop-form-wizard-actions', 'flex', 'gap-1')}>
          <Button size="xs" type="submit" style={CONFIRM_STYLE}>Confirm</Button>
          <Button size="xs" variant="ghost" onClick={onCancel}>Cancel</Button>
        </span>
      </div>
    </form>
  );
}
