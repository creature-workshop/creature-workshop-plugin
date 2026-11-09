/**
 * @file The footer along the bottom of the pane: which build of the plugin
 * this is, and which checkout it was loaded from. When the pane is too
 * narrow for both, the branch wins, since the version is in the lock.
 */

import { cn } from '@hermes/plugin-sdk';
import { useLayoutEffect, useRef, useState } from 'react';
import { useWorkshop } from '../workshop/WorkshopProvider.jsx';

/** The footer is one line that clips, and the box the measuring span is placed against. */
const FOOTER_STYLE = { position: 'relative', overflow: 'hidden', whiteSpace: 'nowrap' };

/** The measuring span: laid out at full width in the footer's font, never seen and never in the way. */
const MEASURE_STYLE = { position: 'absolute', left: 0, top: 0, visibility: 'hidden', whiteSpace: 'nowrap' };

/**
 * The words of the footer: the version, then the branch after a dot when
 * there is one; empty when neither is known yet.
 *
 * @param about The backend's answer to GET /about.
 */
export function footerText(about) {
  return [about.version, about.branch].filter(Boolean).join(' · ');
}

/**
 * The words of the footer when it has only `width` pixels and the full
 * text needs `needed`: the branch alone when there is one and the full text
 * does not fit, else the full text.
 *
 * @param about The backend's answer to GET /about.
 * @param width The footer's inner width in pixels.
 * @param needed The full text's width in pixels.
 */
export function fittedText(about, width, needed) {
  if (about.branch && needed > width) {
    return about.branch;
  }

  return footerText(about);
}

/**
 * The footer: a contentinfo region with the version and the branch, or the
 * branch alone when the two do not fit side by side. The role is set by
 * hand because a footer inside a section has none of its own. The
 * geometry is inline style, not utility classes, so the fitting works in
 * any host, including the test page, which has no stylesheet.
 */
export function Footer() {
  const { about } = useWorkshop();
  const footer = useRef(null);
  const measure = useRef(null);
  const [fit, setFit] = useState({ width: Infinity, needed: 0 });
  useLayoutEffect(fitToRoom(footer, measure, setFit), [about]);

  return (
    <footer
      ref={footer}
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
      style={FOOTER_STYLE}
    >
      <span ref={measure} aria-hidden="true" className={cn('workshop-footer-measure')} style={MEASURE_STYLE}>{footerText(about)}</span>
      {fittedText(about, fit.width, fit.needed)}
    </footer>
  );
}

/**
 * The effect that fits the footer's words to its room: measures the
 * footer's inner width and the full text's width before paint, and again
 * on every resize of the footer, until the footer goes away. It runs again
 * when the words change.
 *
 * @layoutEffect
 * @param footer The ref of the footer.
 * @param measure The ref of the hidden span that holds the full text.
 * @param setFit The setter of the footer's {width, needed}.
 */
function fitToRoom(footer, measure, setFit) {
  return () => {
    const read = () => setFit(roomOf(footer.current, measure.current));
    read();
    const observer = new ResizeObserver(read);
    observer.observe(footer.current);
    return () => observer.disconnect();
  };
}

/**
 * The footer's inner width and the width its full text needs, in pixels.
 *
 * @param footer The footer element.
 * @param measure The hidden span that holds the full text.
 */
function roomOf(footer, measure) {
  return { width: footer.clientWidth - padding(footer), needed: measure.scrollWidth };
}

/**
 * The left and right padding of an element, in pixels, as the browser has resolved it.
 *
 * @param element The element.
 */
function padding(element) {
  const style = getComputedStyle(element);
  return parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
}
