/**
 * @file The Project Info tab's panel: what the selected project's manifest
 * says it is, each field editable in place through the inspector, and the
 * releases its .ops/lock records, which only the release job changes.
 */

import { cn } from '@hermes/plugin-sdk';
import { Field } from '../../inspector/Field.jsx';
import { FieldGroup } from '../../inspector/FieldGroup.jsx';
import { Inspector } from '../../inspector/Inspector.jsx';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { MANIFEST } from './manifest.js';

/** What the panel shows for a release the lock does not record. */
const NONE = 'None yet';

/** The help text of the Latest field. */
const LATEST_HINT = 'The newest release of this project, which may be a prerelease such as 1.2.0-dev.';

/** The help text of the Stable field. */
const STABLE_HINT = 'The newest release of this project that is not a prerelease.';

/**
 * Shows two groups: Manifest, the inspector over the MANIFEST binding; and
 * Versions, the latest and stable releases from .ops/lock, which are
 * read-only, each with an (i) that says what it is. A release the
 * lock does not record shows None yet.
 */
export function ProjectInfoPanel() {
  const { project: remote } = useWorkshop();
  const project = remote.data;

  return (
    <div className={cn('workshop-project-info', 'flex', 'flex-col', 'gap-5')}>
      <Inspector binding={MANIFEST} />
      <FieldGroup title="Versions">
        <Field label="Latest" hint={LATEST_HINT}>{project.release.latest || NONE}</Field>
        <Field label="Stable" hint={STABLE_HINT}>{project.release.stable || NONE}</Field>
      </FieldGroup>
    </div>
  );
}
