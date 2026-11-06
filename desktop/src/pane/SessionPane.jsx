/**
 * @file The pane bound to the Desktop session: the session's directory from
 * the SDK's host state, and the backend call, the timer and the settings
 * event from the plugin context.
 */
import { host, useValue } from '@hermes/plugin-sdk';
import { SETTINGS_CHANGED } from '../events.js';
import { WorkshopPane } from './WorkshopPane.jsx';

/**
 * The pane in the session.
 * @param props The component's props.
 * @param props.ctx The plugin context the SDK hands register().
 * @param props.store The store the pane and the chip share.
 */
export function SessionPane({ ctx, store }) {
  const cwd = useValue(host.state.cwd);
  return (
    <WorkshopPane
      store={store}
      cwd={cwd}
      rest={(path) => ctx.rest(path)}
      every={(fn, ms) => ctx.setInterval(fn, ms)}
      whenSettingsChange={(fn) => ctx.onEvent(SETTINGS_CHANGED, fn)}
    />
  );
}
