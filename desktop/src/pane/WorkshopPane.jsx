/**
 * @file The Workshop pane: the one surface the plugin puts in Desktop. It is
 * empty. Every part of the pane is added on top of this, one ticket at a time.
 */

/** The pane's body: a region named Workshop with nothing in it yet. */
export function WorkshopPane() {
  return <section aria-label="Workshop" className="workshop-pane h-full" />;
}
