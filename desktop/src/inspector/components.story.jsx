/**
 * @file The story the shared component suite mounts: one bound field of a
 * small record, with a commit that keeps what it is sent and shows the last
 * operation, so a test can drive any registered component the same way.
 * The tests are in components.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import './builtins.js';
import { BoundField } from './BoundField.jsx';

/**
 * The record's schema: a required title, a note that may be cleared and has
 * a default, and a count no string component fits.
 */
const SCHEMA = Object.freeze({
  required: ['title'],
  properties: {
    title: { type: 'string', description: 'What it is called.' },
    note: { type: ['string', 'null'], default: 'none' },
    count: { type: 'integer' },
  },
});

/** The record's values before any commit: the note is untouched. */
const VALUES = Object.freeze({ title: 'Notes', count: 3 });

/** What a refusing commit answers. */
const REFUSAL = 'Refused for a reason.';

/**
 * One bound field over the record, and the last operation it committed.
 *
 * @param props The component's props.
 * @param {string} props.component The id of the component to bind.
 * @param {string} [props.fieldKey] The key to bind; `title` when left out.
 * @param {boolean} [props.readOnly] Whether the field only shows its value.
 * @param {boolean} [props.refusing] Whether every commit answers REFUSAL.
 * @param {Record<string, unknown>} [props.values] The record's values; VALUES when left out.
 */
export function Harness({
  component,
  fieldKey = 'title',
  readOnly = false,
  refusing = false,
  values = VALUES,
}) {
  const [record, setRecord] = useState(values);
  const [last, setLast] = useState(null);
  const commit = async (operation) => {
    setLast(operation);
    if (refusing) {
      return REFUSAL;
    }
    setRecord({ ...record, [fieldKey]: operation.op === 'clear' ? null : operation.value });
    return null;
  };

  return (
    <div className={cn('workshop-harness', 'flex', 'flex-col', 'gap-2')}>
      <dl>
        <BoundField
          field={{ key: fieldKey, component, label: 'Field', readOnly }}
          schema={SCHEMA}
          values={record}
          commit={commit}
        />
      </dl>
      <output aria-label="Last commit">{last ? JSON.stringify(last) : ''}</output>
    </div>
  );
}
