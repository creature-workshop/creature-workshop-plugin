/**
 * @file The pane bound to the Desktop session: the session's directory from
 * the SDK's host state, and the backend call, the timer and the settings
 * event from the plugin context.
 */
import { host, useValue } from '@hermes/plugin-sdk';
import { Pane } from './Pane.jsx';

const SETTINGS_CHANGED = 'plugin.creature-workshop.settings.changed';

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
