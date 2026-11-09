/**
 * @file The Workshop pane: the one surface the plugin puts in Desktop. It is
 * a column with a header along the top and a footer along the bottom; every
 * other part of the pane is added between them, one ticket at a time. The
 * state the parts share comes from the WorkshopProvider above the pane.
 */

import { cn } from '@hermes/plugin-sdk';
import { Footer } from './Footer.jsx';
import { Header } from './header/Header.jsx';

/** The pane's body: a region named Workshop, with the header at its top and the footer at its bottom. */
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
      <Footer />
    </section>
  );
}
