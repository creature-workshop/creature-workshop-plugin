/**
 * @file The built-in `switch-select` component, for a key that is either
 * turned off (`false`) or set to one of a list of strings: a switch that
 * says whether it is on, and, while it is, a list that says which.
 */

import { cn, Switch } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { Field } from '../Field.jsx';
import { OptionSelect } from '../OptionSelect.jsx';
import { optionsOf } from '../schema.js';
import { stateText } from '../stateText.js';
import { useCommit } from '../useCommit.js';

/**
 * A switch labelled "<label> enabled" and, beside it, a list labelled
 * `label` while the switch is on, or "Off" while it is off.
 *
 * - Turning the switch off sets `false`.
 * - Turning it on sets the option picked last, or else the schema's
 *   default, or else the last option.
 * - Picking an option sets it.
 *
 * Each saves at once. The string "false" counts as off and is not offered.
 * An untouched key shows its default.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function SwitchSelectField(props) {
  const { label, hint, schema, value, state, readOnly, commit } = props;
  const { save, saving, error } = useCommit(commit);
  const options = choicesOf(schema);
  const current = state === 'set' ? value : schema.default;
  const enabled = options.includes(current);
  const [last, setLast] = useState(enabled ? current : '');
  const disabled = readOnly || saving;

  const pick = (option) => {
    setLast(option);
    save({ op: 'set', value: option });
  };
  const turn = (on) => save({ op: 'set', value: on ? onValue(last, schema.default, options) : false });

  return (
    <Field label={label} hint={hint} error={error}>
      <span className={cn('workshop-switch-select-field', 'flex', 'items-center', 'gap-2')}>
        <Switch size="xs" checked={enabled} aria-label={`${label} enabled`} disabled={disabled} onCheckedChange={turn} />
        {enabled
          ? (
            <OptionSelect
              label={label}
              options={options}
              value={state === 'set' ? current : ''}
              placeholder={stateText(state, String(schema.default ?? ''))}
              disabled={disabled}
              onPick={pick}
            />
          )
          : <span className={cn('workshop-field-text', 'text-(--ui-text-tertiary)')}>Off</span>}
      </span>
    </Field>
  );
}

/**
 * The options the list offers: the schema's strings, less "false", which
 * the switch stands for.
 *
 * @param {object} schema The key's definition.
 *
 * @returns {string[]} The options, in order.
 */
function choicesOf(schema) {
  return optionsOf(schema).filter((option) => option !== 'false');
}

/**
 * The option turning the switch on sets: the one picked last, or else the
 * default when it is an option, or else the last option.
 *
 * @param {string} last The option picked last, or empty.
 * @param {unknown} fallback The schema's default.
 * @param {string[]} options The options.
 */
function onValue(last, fallback, options) {
  if (last) {
    return last;
  }
  return options.includes(fallback) ? fallback : options.at(-1);
}
