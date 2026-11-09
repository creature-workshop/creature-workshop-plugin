/**
 * @file The header along the top of the pane: where the project the pane
 * shows is created, picked and named. It is empty for now; each of those
 * lands in it on a ticket of its own.
 */

/** The header's height while it is empty, so the line under it sits where a line of text would end. */
const HEADER_STYLE = { minHeight: '1.75rem' };

/**
 * The header: a banner region along the top of the pane, with the line
 * under it in the app's tertiary stroke, the footer's mirror. The role is
 * set by hand because a header inside a section has none of its own.
 */
export function Header() {
  return (
    <header role="banner" aria-label="Project" className="workshop-header border-b border-(--ui-stroke-tertiary) px-3 py-1.5" style={HEADER_STYLE} />
  );
}
