/**
 * @file The built-in `switch` component: a flag, turned on or off, saved as
 * soon as it is flipped.
 */

import { cn, Switch } from '@hermes/plugin-sdk';
import { Field } from '../Field.jsx';
import { RemoveButton } from '../RemoveButton.jsx';
import { canClear } from '../schema.js';
import { stateText } from '../stateText.js';
import { useCommit } from '../useCommit.js';

/**
 * A switch showing the key's flag, with On or Off beside it. Flipping it
 * sets the flag at once; a refused save shows its message under it. An
 * untouched or cleared key shows the switch at the schema's default, with
 * "Not set" or "Cleared" beside it. Remove, at the far right, clears a set
 * key where the schema allows it. A read-only field's switch cannot be
 * flipped.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function SwitchField(props) {
  const { label, hint, schema, value, state, required, readOnly, commit } = props;
  const { save, saving, error } = useCommit(commit);
  const on = state === 'set' ? value === true : schema.default === true;
  const removable = !readOnly && state === 'set' && canClear(schema, required);
  const remove = removable ? <RemoveButton label={label} disabled={saving} onClick={() => save({ op: 'clear' })} /> : null;
  const fallback = typeof schema.default === 'boolean' ? onOff(schema.default) : '';

  return (
    <Field label={label} hint={hint} action={remove} error={error}>
      <span className={cn('workshop-switch-field', 'flex', 'items-center', 'gap-2')}>
        <Switch
          size="xs"
          checked={on}
          aria-label={label}
          disabled={readOnly || saving}
          onCheckedChange={(checked) => save({ op: 'set', value: checked })}
        />
        <span className={cn('workshop-field-text', state !== 'set' && 'text-(--ui-text-tertiary)')}>
          {state === 'set' ? onOff(on) : stateText(state, fallback)}
        </span>
      </span>
    </Field>
  );
}

/**
 * "On" or "Off" for a flag.
 *
 * @param {boolean} on The flag.
 */
function onOff(on) {
  return on ? 'On' : 'Off';
}
