/**
 * @file The header's mode when the session holds no git repository.
 */

import { cn } from '@hermes/plugin-sdk';

/** Says that no git repository was found where the session is. */
export function NoRepoHeader() {
  return (
    <span
      className={cn(
        'workshop-no-repos',
        'text-(--ui-text-tertiary)',
      )}
    >
      No repositories detected
    </span>
  );
}
