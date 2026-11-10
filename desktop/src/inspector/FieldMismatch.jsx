/**
 * @file A field whose component cannot draw its key: its name with the
 * error glyph that says why, and its value, read-only.
 */

import { REPORT_INVITE } from '../failures/report.js';
import { Field } from './Field.jsx';
import { FieldValue } from './FieldValue.jsx';

/** What a broken field adds after why: whose problem it is and where to report it. */
const BUG = `This is an unexpected bug in the Workshop plugin, not something you did. ${REPORT_INVITE}`;

/**
 * Shows `label` with Desktop's red error glyph after it, whose tooltip says
 * the pane can't let the user edit the field, why, and that it is a bug in
 * the plugin to report; and below it the key's value as text, with no
 * pencil.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} props.reason Why the binding's component cannot draw the key.
 * @param {unknown} props.value The key's value.
 * @param {'untouched' | 'cleared' | 'set'} props.state The key's state.
 */
export function FieldMismatch({ label, reason, value, state }) {
  return (
    <Field label={label} problem={`I can't let you edit this field: ${reason} ${BUG}`}>
      <FieldValue text={textOf(value)} state={state} />
    </Field>
  );
}

/**
 * A value as the field shows it: a string as it is, anything else as JSON.
 *
 * @param {unknown} value The value.
 */
function textOf(value) {
  return typeof value === 'string' ? value : JSON.stringify(value) ?? '';
}
