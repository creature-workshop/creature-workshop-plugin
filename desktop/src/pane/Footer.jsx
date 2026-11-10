/**
 * @file The footer along the bottom of the pane: which build of the plugin
 * this is, and which checkout it was loaded from. When the pane is too
 * narrow for both, the branch wins, since the version is in the lock. When
 * GET /about failed, it says the Workshop plugin's version is unavailable,
 * centred on one line with Desktop's error glyph, whose tooltip says why
 * and what to try.
 */

import { cn } from '@hermes/plugin-sdk';
import { useLayoutEffect, useRef, useState } from 'react';
import { describe } from '../failures/describe.js';
import { InfoTip } from '../inspector/InfoTip.jsx';
import { useWorkshop } from '../workshop/WorkshopProvider.jsx';
import { FooterBar } from './FooterBar.jsx';

/** What the footer says before GET /about has answered. */
const NOT_YET = Object.freeze({ version: '', branch: '' });

/** What the footer says when GET /about failed. */
const UNAVAILABLE = Object.freeze({ version: 'Workshop plugin version unavailable', branch: '' });

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
 * The footer: the version and the branch in the FooterBar, or the branch
 * alone when the two do not fit side by side. The geometry is inline
 * style, not utility classes, so the fitting works in any host, including
 * the test page, which has no stylesheet.
 */
export function Footer() {
  const { about: remote } = useWorkshop();
  const about = aboutOf(remote);
  const footer = useRef(null);
  const measure = useRef(null);
  const [fit, setFit] = useState({ width: Infinity, needed: 0 });
  useLayoutEffect(fitToRoom(footer, measure, setFit), [about]);

  return (
    <FooterBar ref={footer}>
      <span ref={measure} aria-hidden="true" className={cn('workshop-footer-measure')} style={MEASURE_STYLE}>{footerText(about)}</span>
      {remote.state === 'failure'
        ? (
          <span className={cn('workshop-footer-failed', 'flex', 'items-center', 'gap-1')}>
            {UNAVAILABLE.version}
            <InfoTip label="Version" hint={reasonOf(remote.error)} error />
          </span>
        )
        : fittedText(about, fit.width, fit.needed)}
    </FooterBar>
  );
}

/**
 * The version and branch the footer shows for GET /about's answer: the
 * answer once it arrived, nothing while it loads, and UNAVAILABLE when it
 * failed.
 *
 * @param remote GET /about's answer, as remote data.
 */
function aboutOf(remote) {
  if (remote.state === 'success') {
    return remote.data;
  }
  return remote.state === 'failure' ? UNAVAILABLE : NOT_YET;
}

/**
 * What the footer's (i) says when GET /about failed: what happened, why,
 * and what to try.
 *
 * @param error The error.
 */
function reasonOf(error) {
  const { why, hint } = describe(error);
  return `I couldn't read the plugin's version. ${why} ${hint}`;
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
