/**
 * @file The Workshop pane: the one surface the plugin puts in Desktop. It is
 * a column with a header along the top, the Workshop tabs under it, and a
 * footer along the bottom. The
 * state the parts share comes from the WorkshopProvider above the pane.
 */

import { cn } from '@hermes/plugin-sdk';
import { Footer } from './Footer.jsx';
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
      <Header />
      <WorkshopTabs />
      <Footer />
    </section>
  );
}
