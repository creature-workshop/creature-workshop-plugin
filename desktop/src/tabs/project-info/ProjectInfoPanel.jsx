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

/**
 * Shows two groups: Manifest, the inspector over the MANIFEST binding; and
 * Versions, the latest and stable releases from .ops/lock, which are
 * read-only. A release the lock does not record shows None yet.
 */
export function ProjectInfoPanel() {
  const { project } = useWorkshop();

  return (
    <div className={cn('workshop-project-info', 'flex', 'flex-col', 'gap-5')}>
      <Inspector binding={MANIFEST} />
      <FieldGroup title="Versions">
        <Field label="Latest">{project.release.latest || NONE}</Field>
        <Field label="Stable">{project.release.stable || NONE}</Field>
      </FieldGroup>
    </div>
  );
}
