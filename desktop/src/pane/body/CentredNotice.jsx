/**
 * @file A notice that is the only thing in the pane body: what the pane
 * needs from the user, why, and the button that does it, in the middle of
 * the body.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * The notice fills the pane body and sits in its middle, both ways, with
 * its lines centred, and keeps at least 24px between its contents and the
 * body's edges, so a long line wraps before it reaches the pane's side.
 */
const MIDDLE_STYLE = Object.freeze({
  display: 'flex',
  flex: '1 1 0%',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  gap: '0.5rem',
  minHeight: 0,
  padding: '1.5rem',
  textAlign: 'center',
});

/** A line of the notice has no margin of its own: the notice spaces its lines. */
const LINE_STYLE = Object.freeze({ margin: 0 });

/**
 * A status in the middle of the pane body, centred both ways: `what` in
 * bold, `why` under it, and `children`, such as a button, below.
 *
 * @param props The component's props.
 * @param {string} props.name The notice's class, such as `workshop-setup-notice`.
 * @param {string} props.what What the pane needs, or what is missing.
 * @param {string} props.why Why, or what doing it agrees to.
 * @param [props.children] What goes under the two lines.
 */
export function CentredNotice({ name, what, why, children }) {
  return (
    <div role="status" className={cn(name, 'min-w-0')} style={MIDDLE_STYLE}>
      <p className={cn('workshop-notice-what', 'font-semibold')} style={LINE_STYLE}>{what}</p>
      <p className={cn('workshop-notice-why', 'text-(--ui-text-secondary)')} style={LINE_STYLE}>{why}</p>
      {children}
    </div>
  );
}
