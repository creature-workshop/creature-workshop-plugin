/**
 * @file The stories of the Workshop pane: each named export is the pane in
 * one scenario, with the backend's answer it runs against built in, so a
 * test mounts a story and passes nothing but plain data. Playwright mounts
 * the stories by name; the pane's tests are in pane.ct.jsx beside this file.
 */

import { WorkshopPane } from './WorkshopPane.jsx';

/** The pane's height in every story, in pixels. */
const HEIGHT = 200;

/** The pane's width when a test gives none, in pixels: the width Desktop docks it at. */
const DOCKED_WIDTH = 320;

/** GET /about for a checkout on main. */
const aboutOnMain = async () => ({ version: '0.1.0-dev.9', branch: 'main' });

/** GET /about for a plugin outside any git checkout. */
const aboutOutsideGit = async () => ({ version: '0.1.0-dev.9', branch: '' });

/**
 * The pane loaded from a checkout on main.
 *
 * @param props The story's props.
 * @param props.width The pane's width in pixels.
 */
export function OnMain({ width = DOCKED_WIDTH }) {
  return framed(aboutOnMain, width);
}

/**
 * The pane loaded from outside any git checkout.
 *
 * @param props The story's props.
 * @param props.width The pane's width in pixels.
 */
export function OutsideGit({ width = DOCKED_WIDTH }) {
  return framed(aboutOutsideGit, width);
}

/**
 * The pane in a box of the given width, the way Desktop docks it, over a backend call.
 *
 * @param rest The backend call the pane makes.
 * @param width The box's width in pixels.
 */
function framed(rest, width) {
  return (
    <div className="workshop-story" style={{ width, height: HEIGHT, display: 'flex', flexDirection: 'column' }}>
      <WorkshopPane rest={rest} />
    </div>
  );
}
