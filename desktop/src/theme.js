/**
 * @file The pane's colours, as Hermes Desktop's own theme tokens: each is a
 * CSS variable Desktop defines for the active theme, with a fallback for the
 * test page, which loads no theme. Nothing under desktop/src names a colour
 * by value; it names one of these.
 */

/** A tool that is installed. */
export const INSTALLED = 'var(--ui-green, #3fb950)';

/** A tool that is missing. */
export const MISSING = 'var(--ui-red, #f85149)';

/** Text that is secondary to the point: a note, a count of nothing. */
export const MUTED = 'var(--ui-text-tertiary, #8b949e)';

/** The background of the open tab's button. */
export const OPEN_TAB = 'var(--ui-control-active-background, rgba(127, 127, 127, 0.2))';

/** The background of a tab's button that is not open. */
export const CLOSED_TAB = 'transparent';
