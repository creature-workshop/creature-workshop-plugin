/**
 * @file The inspector: shows a binding's fields, each drawn by the component
 * the binding names, using the record and the schema the store returns.
 */

import { cn } from '@hermes/plugin-sdk';
import { useRecord } from '../hooks/useRecord.js';
import { useSchema } from '../hooks/useSchema.js';
import { useWorkshop } from '../workshop/WorkshopProvider.jsx';
import './builtins.js';
import { BoundField } from './BoundField.jsx';
import { FieldGroup } from './FieldGroup.jsx';

/**
 * Shows the binding's fields under its title, in the binding's order, for
 * the selected project. Keys the binding does not list are left out. The
 * fields appear once both the record and its schema have arrived; if
 * reading the record failed, the reason shows instead.
 *
 * @param props The component's props.
 * @param {object} props.binding What to show, as register in bindings.js returns it.
 */
export function Inspector({ binding }) {
  const { project } = useWorkshop();
  const collection = { ...binding.collection, root: project.root };
  const { record, failure, write } = useRecord({ ...collection, id: binding.record });
  const schema = useSchema(collection);

  return (
    <FieldGroup title={binding.title}>
      {failure && <div role="alert" className={cn('text-destructive')}>{failure.message}</div>}
      {record && schema && binding.fields.map((field) => (
        <BoundField
          key={field.key}
          field={field}
          schema={schema}
          values={record.values}
          commit={(operation) => write({ ...operation, key: field.key })}
        />
      ))}
    </FieldGroup>
  );
}
