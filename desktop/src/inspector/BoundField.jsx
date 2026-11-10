/**
 * @file One field of a binding: the component the binding names, given the
 * key's value and what the schema says about it, or a message saying why
 * it cannot be shown.
 */

import { componentFor } from './components.js';
import { fieldProps } from './fieldProps.js';
import { FieldMismatch } from './FieldMismatch.jsx';
import { misfit } from './fits.js';
import { definitionOf, isRequired, stateOf } from './schema.js';

/**
 * Draws the field with the component its binding names. The name is the
 * binding's label, the schema's title, or the key; the help text is the
 * binding's hint, or else the schema's description. A key the file's
 * schema does not describe is not shown: the project's shellops does not
 * know it yet. A component that is not listed, or that cannot save to the
 * key, shows why instead of an editor.
 *
 * @param props The component's props.
 * @param {object} props.field The bound field, as boundField in bindings.js builds it.
 * @param props.schema The document's schema.
 * @param {Record<string, unknown>} props.values The record's values.
 * @param {(operation: object) => Promise<string | null>} props.commit Writes one operation to this field's key.
 */
export function BoundField({ field, schema, values, commit }) {
  const definition = definitionOf(schema, field.key);
  if (!definition) {
    return null;
  }
  const label = field.label ?? definition.title ?? field.key;
  const component = componentFor(field.component);
  if (!component) {
    return <FieldMismatch label={label} reason={`There is no component named ${field.component}.`} />;
  }
  const reason = misfit(component, field.key, definition);
  if (reason) {
    return <FieldMismatch label={label} reason={reason} />;
  }

  const { Component } = component;
  const props = fieldProps({
    label,
    hint: field.hint ?? definition.description ?? '',
    schema: definition,
    value: values[field.key],
    state: stateOf(values, field.key),
    required: isRequired(schema, field.key),
    readOnly: field.readOnly,
    commit,
  });
  return <Component {...props} />;
}
