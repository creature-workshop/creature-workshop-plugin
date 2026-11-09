/**
 * @file The Workshop pane: the one surface the plugin puts in Desktop. It is
 * a column with a header along the top and a footer along the bottom; every
 * other part of the pane is added between them, one ticket at a time.
 */

import { useEffect, useState } from 'react';
import { loadAbout } from '../about/load.js';
import { Footer } from './Footer.jsx';
import { Header } from './Header.jsx';

/** What the footer shows before the backend has answered. */
const UNKNOWN = { version: '', branch: '' };

/**
 * The pane's body: a region named Workshop, with the header at its top and
 * the footer at its bottom.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 */
export function WorkshopPane({ rest }) {
  const [about, setAbout] = useState(UNKNOWN);
  useEffect(askAbout(rest, setAbout), [rest]);

  return (
    <section aria-label="Workshop" className="workshop-pane flex h-full flex-col">
      <Header />
      <Footer about={about} />
    </section>
  );
}

/**
 * The effect that asks the backend what the plugin is, when the pane mounts
 * and whenever the backend call changes, and keeps the answer unless the
 * pane went away first.
 *
 * @effect
 * @param rest The backend call, taking a path under the plugin's API.
 * @param setAbout The setter of the footer's answer.
 */
function askAbout(rest, setAbout) {
  return () => {
    let open = true;
    loadAbout(rest).then((answer) => open && setAbout(answer));
    return () => { open = false; };
  };
}
