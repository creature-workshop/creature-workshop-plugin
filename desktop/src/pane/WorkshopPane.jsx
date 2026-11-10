/**
 * @file The Workshop pane: the one surface the plugin puts in Desktop. It is
 * a column with a header along the top, the Workshop tabs under it, and a
 * footer along the bottom, each inside an error boundary, so one part's
 * crash leaves the others drawn. A crashed footer says only that the
 * plugin's version is unavailable. The state the parts share comes from the
 * WorkshopProvider above the pane.
 */

import { cn } from '@hermes/plugin-sdk';
import { PartBoundary } from '../failures/PartBoundary.jsx';
import { Footer } from './Footer.jsx';
import { FooterFailed } from './FooterFailed.jsx';
import { Header } from './header/Header.jsx';
import { WorkshopTabs } from './tabs/WorkshopTabs.jsx';

/** The pane's body: a region named Workshop, with the header at its top, the tabs below it, and the footer at its bottom. */
export function WorkshopPane() {
  return (
    <section
      aria-label="Workshop"
      className={cn(
        'workshop-pane',
        'flex',
        'h-full',
        'flex-col',
      )}
    >
      <PartBoundary part="The header">
        <Header />
      </PartBoundary>
      <PartBoundary part="The tabs">
        <WorkshopTabs />
      </PartBoundary>
      <PartBoundary part="The footer" fallback={FooterFailed}>
        <Footer />
      </PartBoundary>
    </section>
  );
}
