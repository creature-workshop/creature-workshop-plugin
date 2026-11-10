/**
 * @file The selector over the session's git repositories, built from the
 * app's own select so it looks and behaves like the rest of Desktop.
 */

import { cn, Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Tip } from '@hermes/plugin-sdk';
import { useId } from 'react';
import { repositoryAt } from '../../../workshop/selection.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';
import { LabelledField } from '../field/LabelledField.jsx';

/** What the Repository label's (i) says. */
const HINT = "Within this chat session's folder, which git repository do you want to inspect?";

/**
 * A select under a small Session Repository label with an (i), listing each repository by name, with a
 * placeholder until one is selected and the selected one's path in a
 * tooltip. A name too long for the trigger ends in an ellipsis rather than
 * running under the state beside it. Selecting one selects it for the
 * whole pane.
 */
export function RepositorySelector() {
  const { repos, repo, select } = useWorkshop();
  const label = useId();

  return (
    <LabelledField id={label} label="Session Repository" hint={HINT}>
      <Select value={repo} onValueChange={select}>
        <Tip label={repositoryAt(repos.data.repos, repo)?.root}>
          <SelectTrigger
            size="xs"
            aria-labelledby={label}
            className={cn(
              'workshop-repo-selector',
              'w-full',
              'min-w-0',
              'overflow-hidden',
            )}
          >
            <SelectValue
              placeholder="Select a repository"
              className={cn(
                'workshop-repo-selector-value',
                'min-w-0',
                'truncate',
              )}
            />
          </SelectTrigger>
        </Tip>
        <SelectContent>
          {repos.data.repos.map((each) => <SelectItem key={each.root} value={each.root}>{each.name}</SelectItem>)}
        </SelectContent>
      </Select>
    </LabelledField>
  );
}
