/**
 * @file The Project Info tab's panel: what the selected project's manifest
 * says it is, each field editable in place through the file store, and the
 * releases its .ops/lock records, which only the release job changes.
 */

import { cn } from '@hermes/plugin-sdk';
import { useRecord } from '../../hooks/useRecord.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { EditableField } from './EditableField.jsx';
import { Field } from './Field.jsx';
import { FieldGroup } from './FieldGroup.jsx';

/** What the panel shows for a release the lock does not record. */
const NONE = 'None yet';

/** The manifest as a record of the file store, less the project's root. */
const MANIFEST = Object.freeze({ kind: 'file', source: 'config/manifest.yaml', id: 'document' });

/**
 * The manifest keys the panel shows and edits, in order, with their labels
 * and whether the manifest requires them.
 */
const FIELDS = Object.freeze([
  { key: 'name', label: 'Name', required: true },
  { key: 'description', label: 'Description', required: true, multiline: true },
  { key: 'command-name', label: 'Command', required: false },
  { key: 'org', label: 'Organization', required: true },
  { key: 'repo', label: 'Repository', required: true },
]);

/**
 * Shows two groups: Manifest, the fields of .ops/config/manifest.yaml, each
 * with a pencil button to edit it, once the manifest is read (or why it
 * could not be); and Versions, the latest and stable releases from
 * .ops/lock, which are read-only. A release the lock does not record shows
 * None yet.
 */
export function ProjectInfoPanel() {
  const { project } = useWorkshop();
  const { record, failure, write } = useRecord({ ...MANIFEST, root: project.root });

  return (
    <div className={cn('workshop-project-info', 'flex', 'flex-col', 'gap-5')}>
      <FieldGroup title="Manifest">
        {failure && <div role="alert" className={cn('text-destructive')}>{failure.message}</div>}
        {record && FIELDS.map((field) => (
          <EditableField
            key={field.key}
            label={field.label}
            value={textOf(record.values[field.key])}
            multiline={field.multiline}
            onSave={(value) => save(field, value, write)}
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
 * A manifest value as the text a field shows: empty when it is untouched,
 * cleared, or not a single value.
 *
 * @param value The value.
 */
function textOf(value) {
  return value === undefined || value === null || typeof value === 'object' ? '' : String(value);
}

/**
 * Saves one field's new text as a set. A required field left empty is
 * refused here, without a call. Resolves to what the field should say, or
 * null on success.
 *
 * @param field The field, from FIELDS.
 * @param {string} value Its new text.
 * @param write Applies one change to the manifest.
 */
async function save(field, value, write) {
  const text = value.trim();
  if (field.required && !text) {
    return `${field.label} cannot be empty.`;
  }
  return write({ op: 'set', key: field.key, value: text });
}
