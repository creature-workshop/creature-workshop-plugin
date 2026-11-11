/**
 * @file Three dots that appear one at a time and start over, the pane's
 * loading spinner in text.
 */

import { cn } from '@hermes/plugin-sdk';
import { useEffect, useState } from 'react';

/** How long each step of the dots shows, in milliseconds. */
const STEP_MS = 400;

/** The dots at each step, from none to three. */
const STEPS = Object.freeze(['', '.', '..', '...']);

/** The dots' width, the width of all three, so the text before them never moves; inline because Desktop's stylesheet has no class for it. */
const DOTS_STYLE = { display: 'inline-block', width: '1.5ch', textAlign: 'left' };

/**
 * `children`, then dots that appear one at a time and start over. With
 * reduced motion asked for, the three dots stay still. The dots are hidden
 * from assistive technology, which reads the text alone.
 *
 * @param props The component's props.
 * @param props.children The text before the dots.
 */
export function LoadingDots({ children }) {
  const [step, setStep] = useState(STEPS.length - 1);
  useEffect(cycleDots(setStep), []);

  return (
    <span className={cn('workshop-loading-dots')}>
      {children}
      <span aria-hidden="true" className={cn('workshop-loading-dots-dots')} style={DOTS_STYLE}>{STEPS[step]}</span>
    </span>
  );
}

/**
 * Moves the dots on one step every STEP_MS, unless the user asked for
 * reduced motion.
 *
 * @effect
 * @param setStep Stores the step.
 */
function cycleDots(setStep) {
  return () => {
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) {
      return undefined;
    }
    setStep(0);
    const timer = setInterval(() => setStep((before) => (before + 1) % STEPS.length), STEP_MS);
    return () => clearInterval(timer);
  };
}
