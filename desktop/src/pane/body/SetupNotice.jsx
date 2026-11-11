/**
 * @file What the pane body shows for a checkout whose branch has no
 * workshop, in place of the tabs, alone and in its middle.
 */

import { CentredNotice } from './CentredNotice.jsx';
import { setupMessage } from './setupMessage.js';

/**
 * A status in the middle of the pane body saying what the checkout named
 * `name` is missing in `state`, and why or what to do about it, with
 * `children`, such as a button that sets it up, below. Nothing when the
 * checkout is ready.
 *
 * @param props The component's props.
 * @param {'no-workshop' | 'ready'} props.state Whether the checkout has a workshop.
 * @param {string} props.name The checkout's folder name.
 * @param [props.children] What goes under the message.
 */
export function SetupNotice({ state, name, children }) {
  const message = setupMessage(state, name);
  if (!message) {
    return null;
  }

  return <CentredNotice name="workshop-setup-notice" what={message.what} why={message.why}>{children}</CentredNotice>;
}
