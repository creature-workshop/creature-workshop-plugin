/**
 * @file The pane for the focused session: the one place the pane reads
 * Desktop's own state, the session's directory, so everything under it
 * takes that from the WorkshopProvider and can be mounted in a test
 * without Desktop.
 */

import { host, useValue } from '@hermes/plugin-sdk';
import { WorkshopProvider } from '../workshop/WorkshopProvider.jsx';
import { WorkshopPane } from './WorkshopPane.jsx';

/**
 * The Workshop pane for the session's directory, following it as the focused session changes.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 */
export function SessionPane({ rest }) {
  const cwd = useValue(host.state.cwd);
  return (
    <WorkshopProvider rest={rest} cwd={cwd}>
      <WorkshopPane />
    </WorkshopProvider>
  );
}
