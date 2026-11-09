/**
 * @file The Project Info tab's panel: what the selected project's manifest
 * says it is, each field editable in place, and the releases its .ops/lock
 * records, which only the release job changes.
 */

import { cn } from '@hermes/plugin-sdk';
import { client } from '../../client/index.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { EditableField } from './EditableField.jsx';
import { Field } from './Field.jsx';
import { FieldGroup } from './FieldGroup.jsx';

/** What the panel shows for a release the lock does not record. */
const NONE = 'None yet';

/**
 * The manifest fields the panel shows and edits, in order: the manifest
 * key, the label, how to read the value from GET /project's answer, and
 * whether the manifest requires it.
 */
const FIELDS = Object.freeze([
  { key: 'name', label: 'Name', read: (project) => project.manifest?.name ?? project.name, required: true },
  { key: 'description', label: 'Description', read: (project) => project.manifest?.description ?? '', required: true, multiline: true },
  { key: 'command-name', label: 'Command', read: (project) => project.manifest?.command_name ?? '', required: false },
  { key: 'org', label: 'Organization', read: (project) => project.manifest?.org ?? '', required: true },
  { key: 'repo', label: 'Repository', read: (project) => project.manifest?.repo ?? '', required: true },
]);

/**
 * Shows two groups: Manifest, the fields of .ops/config/manifest.yaml, each
 * with a pencil button to edit it; and Versions, the latest and stable
 * releases from .ops/lock, which are read-only. A release the lock does not record
 * shows None yet.
 */
export function ProjectInfoPanel() {
  const { project, updateProject } = useWorkshop();

  return (
    <div className={cn('workshop-project-info', 'flex', 'flex-col', 'gap-5')}>
      <FieldGroup title="Manifest">
        {FIELDS.map((field) => (
          <EditableField
            key={field.key}
            label={field.label}
            value={field.read(project)}
            multiline={field.multiline}
            onSave={(value) => save(project, field, value, updateProject)}
          />
        ))}
      </FieldGroup>
      <FieldGroup title="Versions">
        <Field label="Latest">{project.release.latest || NONE}</Field>
        <Field label="Stable">{project.release.stable || NONE}</Field>
      </FieldGroup>
    </div>
  );
}

/**
 * Saves one field through POST /project/manifest, and puts the answer in
 * the pane's shared state. Resolves to an error message, or null on success.
 * A required field left empty is refused here, without a call.
 *
 * @param project The answer to GET /project.
 * @param field The field, from FIELDS.
 * @param {string} value Its new value.
 * @param updateProject Replaces the project in the pane's shared state.
 */
async function save(project, field, value, updateProject) {
  const text = value.trim();
  if (field.required && !text) {
    return `${field.label} cannot be empty.`;
  }
  const answer = await client.changeManifest(project.root, field.key, text);
  if (answer.error) {
    return answer.error;
  }
  updateProject(answer);
  return null;
}
