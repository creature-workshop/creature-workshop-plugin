/**
 * @file The pane bound to the Desktop session: the session's directory from
 * the SDK's host state, and the backend call, the timer and the settings
 * event from the plugin context.
 */
import { host, useValue } from '@hermes/plugin-sdk';
import { Pane } from './Pane.jsx';

/** The event Hermes broadcasts when the plugin's settings are saved. */
const SETTINGS_CHANGED = 'plugin.creature-workshop.settings.changed';

/**
 * The pane in the session.
 * @param props The component's props.
 * @param props.ctx The plugin context the SDK hands register().
 * @param props.store The store the pane and the chip share.
 */
export function PaneWithSession({ ctx, store }) {
  const cwd = useValue(host.state.cwd);
  return (
    <Pane
      store={store}
      cwd={cwd}
      rest={(path) => ctx.rest(path)}
      every={(fn, ms) => ctx.setInterval(fn, ms)}
      whenSettingsChange={(fn) => ctx.onEvent(SETTINGS_CHANGED, fn)}
    />
  );
}
