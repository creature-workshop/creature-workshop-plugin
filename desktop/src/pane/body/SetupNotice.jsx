/**
 * @file What the pane body shows for a checkout that is not set up for
 * shellops, in place of the tabs.
 */

import { cn } from '@hermes/plugin-sdk';
import { setupMessage } from './setupMessage.js';

/**
 * A status saying what the checkout named `name` is missing in `state`, and
 * why or what to do about it, with any command it names in code type.
 * Nothing when the checkout is ready.
 *
 * @param props The component's props.
 * @param {'no-workshop' | 'not-set-up' | 'ready'} props.state How far the checkout is set up.
 * @param {string} props.name The checkout's folder name.
 */
export function SetupNotice({ state, name }) {
  const message = setupMessage(state, name);
  if (!message) {
    return null;
  }

  return (
    <div role="status" className={cn('workshop-setup-notice', 'flex', 'min-w-0', 'flex-col', 'gap-1', 'px-2', 'py-2')}>
      <p className={cn('workshop-setup-what', 'font-semibold')}>{message.what}</p>
      <p className={cn('workshop-setup-why', 'text-(--ui-text-secondary)')}>{message.why}</p>
      {message.code && <code className={cn('workshop-setup-code', 'self-start', 'font-mono', 'text-(--ui-text-secondary)')}>{message.code}</code>}
    </div>
  );
}
