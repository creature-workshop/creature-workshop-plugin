/**
 * @file The built-in `select` component: one of the strings a key's schema
 * lists in its `enum`, picked from a list, saved as soon as it is picked.
 */

import { Field } from '../Field.jsx';
import { OptionSelect } from '../OptionSelect.jsx';
import { RemoveButton } from '../RemoveButton.jsx';
import { canClear, optionsOf } from '../schema.js';
import { stateText } from '../stateText.js';
import { useCommit } from '../useCommit.js';

/**
 * A list of the schema's options, showing the key's value. Picking an
 * option sets it at once; a refused save shows its message under the list.
 * An untouched key shows "Not set" with the schema's default, and a cleared
 * one "Cleared". Remove, at the far right, clears a set key where the
 * schema allows it. A read-only field's list cannot be opened.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function SelectField(props) {
  const { label, hint, schema, value, state, required, readOnly, commit } = props;
  const { save, saving, error } = useCommit(commit);
  const removable = !readOnly && state === 'set' && canClear(schema, required);
  const remove = removable ? <RemoveButton label={label} disabled={saving} onClick={() => save({ op: 'clear' })} /> : null;

  return (
    <Field label={label} hint={hint} action={remove} error={error}>
      <OptionSelect
        label={label}
        options={optionsOf(schema)}
        value={state === 'set' ? value : ''}
        placeholder={stateText(state, schema.default ?? '')}
        disabled={readOnly || saving}
        onPick={(option) => save({ op: 'set', value: option })}
      />
    </Field>
  );
}
