/**
 * @file The bar along the bottom of the pane that the footer draws in,
 * whether it shows the plugin's version or says the footer failed.
 */

import { cn } from '@hermes/plugin-sdk';

/** The bar is one line that clips, and the box the footer's measuring span is placed against. */
const BAR_STYLE = { position: 'relative', overflow: 'hidden', whiteSpace: 'nowrap' };

/**
 * A contentinfo region along the bottom of the pane, with the line above it
 * in the app's tertiary stroke, holding `children` on one line. The role is
 * set by hand because a footer inside a section has none of its own.
 *
 * @param props The component's props.
 * @param [props.ref] A ref to the footer element, for measuring it.
 * @param props.children What the bar holds.
 */
export function FooterBar({ ref, children }) {
  return (
    <footer
      ref={ref}
      role="contentinfo"
      className={cn(
        'workshop-footer',
        'mt-auto',
        'border-t',
        'border-(--ui-stroke-tertiary)',
        'px-3',
        'py-1.5',
        'text-[0.6875rem]',
        'text-(--ui-text-tertiary)',
      )}
      style={BAR_STYLE}
    >
      {children}
    </footer>
  );
}
