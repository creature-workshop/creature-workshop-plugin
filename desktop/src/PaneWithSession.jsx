/**
 * @file The pane bound to the Desktop session: the session's directory from
 * the SDK's host state, the backend call and the timer from the plugin
 * context.
 */
import { host, useValue } from '@hermes/plugin-sdk';
import { Pane } from './Pane.jsx';

export function PaneWithSession({ ctx, store }) {
  const cwd = useValue(host.state.cwd);
  return <Pane store={store} cwd={cwd} rest={(path) => ctx.rest(path)} every={(fn, ms) => ctx.setInterval(fn, ms)} />;
}
