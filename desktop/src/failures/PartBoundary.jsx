/**
 * @file The error boundary around each part of the pane, so one part's
 * crash leaves the rest drawn.
 */

import { ErrorBoundary } from 'react-error-boundary';
import { PartFailed } from './PartFailed.jsx';

/**
 * Draws `children` until one of them throws while drawing, then draws
 * `fallback` for `part` in their place, and writes the error and where it
 * happened to the console. The fallback's Try again draws the children
 * again. The catching is react-error-boundary's, since React catches a
 * crash only in a class component.
 *
 * @param props The component's props.
 * @param {string} props.part The part's name, such as "The header".
 * @param [props.fallback] What to draw after a crash, given `{part, error, onRetry}`; PartFailed when left out.
 * @param props.children The part.
 */
export function PartBoundary({ part, fallback: Fallback = PartFailed, children }) {
  return (
    <ErrorBoundary
      fallbackRender={({ error, resetErrorBoundary }) => <Fallback part={part} error={error} onRetry={resetErrorBoundary} />}
      onError={(error, info) => console.error(`${part} stopped working.`, error, info.componentStack)}
    >
      {children}
    </ErrorBoundary>
  );
}
