/**
 * @file The Project Info tab's panel: what the selected project's manifest
 * says it is, and the releases its .ops/lock records.
 */

import { cn } from '@hermes/plugin-sdk';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';

/** What the panel shows for a release the lock does not record. */
const NONE = 'None yet';

/**
 * Lists the project's name, description, command, repository, latest
 * release and stable release. A manifest field that is not set is left
 * out; a release the lock does not record shows None yet.
 */
export function ProjectInfoPanel() {
  const { project } = useWorkshop();

  return (
    <dl
      className={cn(
        'workshop-project-info',
        'grid',
        'grid-cols-[auto_1fr]',
        'gap-x-3',
        'gap-y-1',
      )}
    >
      {rows(project).map(([term, value]) => [
        <dt key={`${term}-term`} className={cn('text-(--ui-text-tertiary)')}>{term}</dt>,
        <dd key={`${term}-value`}>{value}</dd>,
      ])}
    </dl>
  );
}

/**
 * Returns the panel's rows as `[term, value]` pairs, leaving out the
 * manifest fields that are not set.
 *
 * @param project The answer to GET /project.
 */
function rows(project) {
  const identity = project.identity ?? {};
  const named = [
    ['Name', project.name],
    ['Description', identity.description],
    ['Command', identity.command_name],
    ['Repository', repository(identity)],
  ].filter(([, value]) => value);
  return [...named, ['Latest', project.release.latest || NONE], ['Stable', project.release.stable || NONE]];
}

/**
 * Returns the repository as `org/repo`, or just the part that is set.
 *
 * @param identity The project's identity from GET /project.
 */
function repository(identity) {
  return [identity.org, identity.repo].filter(Boolean).join('/');
}
