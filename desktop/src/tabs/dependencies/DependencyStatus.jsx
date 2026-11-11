/**
 * @file Whether one dependency is installed, as the end of its row says it.
 */

import { cn, Codicon } from '@hermes/plugin-sdk';
import { LoadingDots } from '../../pane/body/LoadingDots.jsx';
import { STATUS } from './dependencies.js';

/**
 * "Installed" with a check mark, "Missing" in the error color with a
 * warning mark, or "Checking" with dots while the check runs; nothing when
 * the status is unknown, since the tab says once, above the list, that it
 * could not check.
 *
 * @param props The component's props.
 * @param {string} props.status One of STATUS.
 */
export function DependencyStatus({ status }) {
  if (status === STATUS.checking) {
    return <span className={cn('workshop-dependency-checking', 'text-(--ui-text-tertiary)')}><LoadingDots>Checking</LoadingDots></span>;
  }
  if (status === STATUS.installed) {
    return <span className={cn('workshop-dependency-installed', 'flex', 'items-center', 'gap-1', 'text-(--ui-text-secondary)')}><Codicon name="check" />Installed</span>;
  }
  if (status === STATUS.missing) {
    return <span className={cn('workshop-dependency-missing', 'flex', 'items-center', 'gap-1', 'text-destructive')}><Codicon name="warning" />Missing</span>;
  }

  return null;
}
