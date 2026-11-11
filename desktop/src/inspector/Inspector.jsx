/**
 * @file The inspector: shows a binding's fields, each drawn by the component
 * the binding names, using the record and the schema the store returns.
 */

import { useState } from 'react';
import { FailureNotice } from '../failures/FailureNotice.jsx';
import { useRecord } from '../hooks/useRecord.js';
import { useSchema } from '../hooks/useSchema.js';
import { useWorkshop } from '../workshop/WorkshopProvider.jsx';
import './builtins.js';
import { BoundField } from './BoundField.jsx';
import { FieldGroup } from './FieldGroup.jsx';

/**
 * Shows the binding's fields under its title, in the binding's order, for
 * the selected project. Keys the binding does not list are left out. The
 * fields appear once both the record and its schema have arrived. When
 * reading either failed, it says so in their place, with why, what to try,
 * and Try again, which reads both again. A record that does not exist is
 * not a failure when `missing` is given: the group shows what `missing`
 * draws in the fields' place. `missing` is given `reread`, which reads the
 * record and the schema again, for when it has made the record.
 *
 * @param props The component's props.
 * @param {object} props.binding What to show, as register in bindings.js returns it.
 * @param {(reread: () => void) => import('react').ReactNode} [props.missing] Draws what to show when the record does not exist, such as a button that creates it.
 */
export function Inspector({ binding, missing = null }) {
  const { project } = useWorkshop();
  const [attempt, setAttempt] = useState(0);
  const store = { ...binding.store, root: project.data.root };
  const { record, write } = useRecord({ ...store, id: binding.record }, attempt);
  const schema = useSchema(store, attempt);
  const absent = Boolean(missing) && notFound(record);
  const failed = !absent && [record, schema].find((remote) => remote.state === 'failure');

  return (
    <FieldGroup title={binding.title}>
      {absent && missing(() => setAttempt((before) => before + 1))}
      {failed && (
        <FailureNotice
          what={`I couldn't read the ${binding.title} fields from ${binding.store.source}.`}
          error={failed.error}
          onRetry={() => setAttempt(attempt + 1)}
        />
      )}
      {record.state === 'success' && schema.state === 'success' && binding.fields.map((field) => (
        <BoundField
          key={field.key}
          field={field}
          schema={schema.data}
          values={record.data.values}
          commit={(operation) => write({ ...operation, key: field.key })}
        />
      ))}
    </FieldGroup>
  );
}

/**
 * Whether reading the record failed because it does not exist.
 *
 * @param record The record, as remote data.
 */
function notFound(record) {
  return record.state === 'failure' && record.error.code === 'NOT_FOUND';
}
