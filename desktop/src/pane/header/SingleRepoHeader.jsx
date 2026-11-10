/**
 * @file The header's mode when the session holds one git repository: its
 * name and its state, read-only.
 */

import { cn } from '@hermes/plugin-sdk';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { RepoStatus } from './RepoStatus.jsx';

/** The repository's name, then its state the way a shell prompt shows it. */
export function SingleRepoHeader() {
  const { repos } = useWorkshop();
  const [repo] = repos.data.repos;
  return (
    <>
      <span
        className={cn(
          'workshop-repo-name',
          'truncate',
          'text-(--ui-text-secondary)',
        )}
        title={repo.root}
      >
        {repo.name}
      </span>
      <RepoStatus root={repo.root} />
    </>
  );
}
