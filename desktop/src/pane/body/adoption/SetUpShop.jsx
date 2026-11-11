/**
 * @file The adoption wizard in the pane body: the manifest's fields, the
 * commit choice and the approval notice, then the adoption itself.
 */

import { cn } from '@hermes/plugin-sdk';
import { useMemo } from 'react';
import { FailureNotice } from '../../../failures/FailureNotice.jsx';
import { Wizard } from '../../../wizard/Wizard.jsx';
import { LoadingDots } from '../LoadingDots.jsx';
import { adoptionSteps } from './adoptionSteps.js';
import { useSetUpShop } from './useSetUpShop.js';

/**
 * The wizard for setting up shop in the checkout at `root`, through
 * whichever implementation is registered, starting on GET
 * /project/adoption's suggestions and the agent's guesses; while those
 * load it says "Reading <name>" with dots. While the adoption runs it says
 * "Setting up shop" with dots; when recording the approval or the adoption
 * fails, which of the two and why, with Try again. Cancel calls `onCancel`,
 * and an adoption that went through calls `onDone`.
 *
 * @param props The component's props.
 * @param {string} props.root The checkout's root.
 * @param {string} props.name The checkout's folder name.
 * @param {() => void} props.onCancel Leaves the wizard.
 * @param {() => void} [props.onDone] Called once shop is set up.
 */
export function SetUpShop({ root, name, onCancel, onDone }) {
  const { suggested, reload, attempt, adopt } = useSetUpShop(root, onDone);
  const steps = useMemo(() => suggested.state === 'success' && adoptionSteps(suggested.data, suggested.data.guessed), [suggested]);
  if (suggested.state === 'failure') {
    return <FailureNotice what={`I couldn't read ${name} to fill in the form.`} error={suggested.error} onRetry={reload} />;
  }
  if (suggested.state === 'loading') {
    return <p className={cn('workshop-set-up-shop-reading', 'text-(--ui-text-secondary)')}><LoadingDots>{`Reading ${name}`}</LoadingDots></p>;
  }
  if (attempt.phase === 'adopting') {
    return <p className={cn('workshop-set-up-shop-running', 'text-(--ui-text-secondary)')}><LoadingDots>Setting up shop</LoadingDots></p>;
  }
  if (attempt.phase === 'failed') {
    return <FailureNotice what={whatFailed(attempt.step, name)} error={attempt.error} onRetry={() => adopt(attempt.answers)} />;
  }

  return steps && <Wizard tool="shop" steps={steps} onFinish={adopt} onCancel={onCancel} />;
}

/**
 * What to say failed: recording the approval, before anything was written
 * to the checkout, or the adoption.
 *
 * @param {'approval' | 'adoption'} step The step that failed.
 * @param {string} name The checkout's folder name.
 */
function whatFailed(step, name) {
  return step === 'approval'
    ? `I couldn't record your approval of ${name}, so I haven't set up shop yet.`
    : `I couldn't set up shop in ${name}.`;
}
