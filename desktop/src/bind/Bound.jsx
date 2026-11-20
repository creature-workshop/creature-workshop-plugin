/**
 * @file The wrapper the pane's JSX runtime puts around every component
 * that is given a `bind` prop. It is the one place a component's data
 * reaches the checkout's synced stores, so the component itself is
 * ordinary React: props in, callbacks out.
 */

import { useCallback, useSyncExternalStore } from 'react';
import { FailureNotice } from '../failures/FailureNotice.jsx';
import { useCommit } from '../inspector/useCommit.js';
import { useWorkshop } from '../workshop/WorkshopProvider.jsx';
import { propsFor } from './props.js';
import { targetOf } from './target.js';

/**
 * Draws `bound` with the data its binding names, and draws it again
 * whenever that store changes, whether a read answered something new or a
 * write was queued, confirmed or refused.
 *
 * The component is drawn only once the data has arrived, with the props
 * props.js lists for the binding and every other prop it was given. Until
 * then the wrapper draws `loading`, which is nothing unless one is given.
 * When the data could not be read it draws `failed(error, reread)`, or,
 * when none is given, a notice that names the file with Try again.
 *
 *     <TextField label="Name" bind={{kind: 'file', source: 'config/manifest.yaml', record: 'document', key: 'name'}} />
 *
 * @param props The wrapper's props, and the component's own.
 * @param props.bound The component to draw.
 * @param {{kind: string, source: string, record?: string, key?: string}} props.bind What the component is bound to.
 * @param [props.loading] What to draw while the data has not arrived.
 * @param {(error: object, reread: () => void) => unknown} [props.failed] Draws what to show when the data could not be read.
 */
export function Bound({ bound: Component, bind, loading = null, failed = null, ...props }) {
  const { synced } = useWorkshop();
  const { kind, source } = bind;
  const follow = useCallback((listen) => synced.follow({ kind, source }, listen), [synced, kind, source]);
  const view = useSyncExternalStore(follow, () => synced.view({ kind, source }));
  const write = useCallback((operation) => synced.write({ kind, source }, operation), [synced, kind, source]);
  const reread = useCallback(() => synced.read(), [synced]);
  const { save, saving, error } = useCommit(write);
  const target = targetOf(bind, view);
  if (target.state === 'loading') {
    return loading;
  }
  if (target.state === 'failure') {
    return failed ? failed(target.error, reread) : <FailureNotice what={`I couldn't read ${source}.`} error={target.error} onRetry={reread} />;
  }

  return <Component {...props} {...propsFor(bind, target.data, { write, save, saving, error, reread })} />;
}
