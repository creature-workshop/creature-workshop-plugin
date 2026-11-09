/**
 * @file A repository's state in the header, the way a shell prompt shows it,
 * read again on the pane's refresh interval.
 */

import { cn } from '@hermes/plugin-sdk';
import { client } from '../../client/index.js';
import { usePolled } from '../../hooks/usePolled.js';
import { promptText, promptWords } from '../../repos/prompt.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';

/**
 * The prompt for the repository at root, with the same in words as its
 * tooltip; nothing until the backend has answered.
 *
 * @param props The component's props.
 * @param props.root The repository's root.
 */
export function RepoStatus({ root }) {
  const { repos } = useWorkshop();
  const status = usePolled(() => client.repoStatus(root), repos.refresh_seconds, root);

  return status && (
    <span
      className={cn(
        'workshop-repo-status',
        'shrink-0',
        'text-(--ui-text-tertiary)',
      )}
      title={promptWords(status)}
    >
      {promptText(status)}
    </span>
  );
}
