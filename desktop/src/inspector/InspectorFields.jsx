/**
 * @file The fields of an inspector binding, drawn from one record. The
 * inspector binds this component to the binding's record, so it receives
 * the record's values, its schema and the way to write to it as props.
 */

import { BoundField } from './BoundField.jsx';

/**
 * One BoundField for each field the binding lists, in the binding's order.
 * A field saves by writing one operation to its own key of the record.
 *
 * @param props The component's props.
 * @param {object} props.binding What to show, as register in bindings.js returns it.
 * @param {Record<string, unknown>} props.value The record's values.
 * @param {object} props.schema The JSON Schema that describes the record.
 * @param {(operation: object) => Promise<string | null>} props.write Writes one operation to the record; resolves to null, or to the message to show.
 */
export function InspectorFields({ binding, value, schema, write }) {
  return binding.fields.map((field) => (
    <BoundField
      key={field.key}
      field={field}
      schema={schema ?? {}}
      values={value}
      commit={(operation) => write({ ...operation, key: field.key })}
    />
  ));
}
