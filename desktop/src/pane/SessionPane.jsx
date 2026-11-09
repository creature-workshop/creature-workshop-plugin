/**
 * @file The pane for the focused session: the one place the pane reads
 * Desktop's own state. It makes the focused chat session the pane's
 * subject, so everything under it takes the subject from the
 * WorkshopProvider and can be mounted in a test without Desktop.
 */

import { host, useValue } from '@hermes/plugin-sdk';
import { useMemo } from 'react';
import { sessionSubject } from '../subject.js';
import { WorkshopProvider } from '../workshop/WorkshopProvider.jsx';
import { WorkshopPane } from './WorkshopPane.jsx';

/**
 * The Workshop pane about the focused chat session, following the focus as it moves.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 */
export function SessionPane({ rest }) {
  const sessionId = useValue(host.state.focusedStoredSessionId);
  const folder = useValue(host.state.cwd);
  const subject = useMemo(() => sessionSubject(sessionId, folder), [sessionId, folder]);
  return (
    <WorkshopProvider rest={rest} subject={subject}>
      <WorkshopPane />
    </WorkshopProvider>
  );
}
