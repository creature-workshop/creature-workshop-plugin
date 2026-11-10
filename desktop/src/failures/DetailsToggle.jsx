/**
 * @file The Show details toggle under a failure: the debugging information,
 * hidden until the user asks for it.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useState } from 'react';

/**
 * A small "Show details" button that reveals `details` as preformatted
 * text on a line of its own, and turns into "Hide details". It sits in a
 * row that wraps, beside the failure's other buttons.
 *
 * @param props The component's props.
 * @param {string} props.details The debugging information.
 */
export function DetailsToggle({ details }) {
  const [shown, setShown] = useState(false);

  return (
    <>
      <Button size="xs" variant="ghost" aria-expanded={shown} onClick={() => setShown(!shown)}>
        {shown ? 'Hide details' : 'Show details'}
      </Button>
      {shown && (
        <pre className={cn('workshop-failure-details', 'w-full', 'whitespace-pre-wrap', 'text-(--ui-text-tertiary)')}>{details}</pre>
      )}
    </>
  );
}
