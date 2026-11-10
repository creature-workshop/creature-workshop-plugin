/**
 * @file Registers the built-in field components. Importing this module is
 * what makes them available to bindings.
 */

import { register } from './components.js';
import { MultilineField } from './components/MultilineField.jsx';
import { NumberField } from './components/NumberField.jsx';
import { SelectField } from './components/SelectField.jsx';
import { SwitchField } from './components/SwitchField.jsx';
import { SwitchSelectField } from './components/SwitchSelectField.jsx';
import { TextField } from './components/TextField.jsx';

/** The `text` component: a one-line string. */
export const TEXT = register({ id: 'text', stores: { type: 'string' }, Component: TextField });

/** The `multiline` component: a string edited in a text area. */
export const MULTILINE = register({ id: 'multiline', stores: { type: 'string' }, Component: MultilineField });

/** The `select` component: one of the strings the schema's `enum` lists. */
export const SELECT = register({ id: 'select', stores: { type: 'string' }, Component: SelectField });

/** The `switch` component: a flag. */
export const SWITCH = register({ id: 'switch', stores: { type: 'boolean' }, Component: SwitchField });

/** The `number` component: a number, whole where the key allows only integers. */
export const NUMBER = register({ id: 'number', stores: { type: 'number' }, Component: NumberField });

/** The `switch-select` component: off (`false`), or one of the strings the schema lists. */
export const SWITCH_SELECT = register({
  id: 'switch-select',
  stores: { type: ['string', 'boolean'] },
  Component: SwitchSelectField,
});
