/**
 * @file The stories of Wizard: a stand-in implementation of the contract
 * that lists the steps it is given and finishes with fixed answers, so a
 * test sees what any implementation receives. The tests are in wizard.ct.jsx
 * beside this file.
 */

import { register } from './implementation.js';
import { confirm, dialog, prompt } from './steps.js';
import { Wizard } from './Wizard.jsx';

/** The steps in every story. */
const STEPS = [dialog('Let us set up shop.'), prompt('What is the project called?', 'name', 'notes'), confirm('Adopt it now?', 'adopt')];

/** The answers the stand-in finishes with. */
const ANSWERS = { name: 'notes', adopt: 'yes' };

/**
 * A stand-in implementation: the tool as a heading, each step's text in a
 * list, and a Finish button that finishes with ANSWERS.
 *
 * @param {import('./implementation.js').WizardProps} props The wizard's props.
 */
function StandIn({ tool, steps, onFinish }) {
  return (
    <section aria-label={`Set up ${tool}`}>
      <ol>
        {steps.map((step) => <li key={step.text}>{step.text}</li>)}
      </ol>
      <button type="button" onClick={() => onFinish(ANSWERS)}>Finish</button>
    </section>
  );
}

/**
 * The wizard with the stand-in registered.
 *
 * @param props The story's props.
 * @param props.onFinish Called with the answers.
 */
export function Registered({ onFinish }) {
  register(StandIn);
  return <Wizard tool="notes" steps={STEPS} onFinish={onFinish} onCancel={() => {}} />;
}

/** The wizard with no implementation registered. */
export function Unregistered() {
  register(null);
  return (
    <main aria-label="Pane">
      <Wizard tool="notes" steps={STEPS} onFinish={() => {}} onCancel={() => {}} />
    </main>
  );
}
