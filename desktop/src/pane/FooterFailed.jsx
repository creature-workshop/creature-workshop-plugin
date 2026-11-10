/**
 * @file What the footer shows when its own code crashed: one quiet line,
 * since the footer only ever shows the plugin's version.
 */

import { cn } from '@hermes/plugin-sdk';
import { InfoTip } from '../inspector/InfoTip.jsx';
import { FooterBar } from './FooterBar.jsx';

/**
 * "Workshop plugin version unavailable" in the FooterBar, centred on one
 * line with Desktop's error glyph, whose tooltip says the footer's code
 * went wrong and gives the error's message.
 *
 * @param props The component's props, as PartBoundary gives its fallback.
 * @param {Error} props.error What the footer threw.
 */
export function FooterFailed({ error }) {
  return (
    <FooterBar>
      <span className={cn('workshop-footer-failed', 'flex', 'items-center', 'gap-1')}>
        Workshop plugin version unavailable
        <InfoTip label="Version" hint={`Something in the footer's code went wrong: ${error?.message}`} error />
      </span>
    </FooterBar>
  );
}
