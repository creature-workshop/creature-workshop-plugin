/**
 * @file The selector over the session's git repositories, built from the
 * app's own select so it looks and behaves like the rest of Desktop.
 */

import { cn, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@hermes/plugin-sdk';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';

/**
 * A select named Repository, listing each repository by name, with a
 * placeholder until one is selected. Selecting one selects it for the whole pane.
 */
export function RepositorySelector() {
  const { repos, selected, select } = useWorkshop();
  return (
    <Select value={selected} onValueChange={select}>
      <SelectTrigger
        aria-label="Repository"
        className={cn(
          'workshop-repo-selector',
          'min-w-0',
          'max-w-[60%]',
          'text-[0.6875rem]',
        )}
      >
        <SelectValue placeholder="Select a repository" />
      </SelectTrigger>
      <SelectContent>
        {repos.repos.map((repo) => <SelectItem key={repo.root} value={repo.root} title={repo.root}>{repo.name}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}
