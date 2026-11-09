/**
 * @file The header's mode when the session holds several git repositories:
 * a selector over them, none selected at first, and the state of the one
 * selected.
 */

import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { RepositorySelector } from './RepositorySelector.jsx';
import { RepoStatus } from './RepoStatus.jsx';

/** The selector, then the selected repository's state the way a shell prompt shows it. */
export function MultiRepoHeader() {
  const { selected } = useWorkshop();
  return (
    <>
      <RepositorySelector />
      {selected && <RepoStatus root={selected} />}
    </>
  );
}
