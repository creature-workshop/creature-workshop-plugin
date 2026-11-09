/**
 * @file The one way the plugin shows a wizard: Wizard checks the steps and
 * renders the implementation of the contract that is registered.
 */

import { useMemo } from 'react';
import { validateTargets } from './flow.js';
import { registered } from './implementation.js';

/**
 * A wizard over `steps`, drawn by the registered implementation; nothing
 * when none is registered. Throws when a step jumps to an id no step has.
 *
 * @param {import('./implementation.js').WizardProps} props The wizard's props.
 */
export function Wizard({ tool, steps, onFinish, onCancel }) {
  useMemo(() => validateTargets(steps), [steps]);
  const Implementation = registered();

  return Implementation && <Implementation tool={tool} steps={steps} onFinish={onFinish} onCancel={onCancel} />;
}
