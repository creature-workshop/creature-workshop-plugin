/**
 * @file Registers the built-in field components. Importing this module is
 * what makes them available to bindings.
 */

import { register } from './components.js';
import { MultilineField } from './components/MultilineField.jsx';
import { TextField } from './components/TextField.jsx';

/** The `text` component: a one-line string. */
export const TEXT = register({ id: 'text', stores: { type: 'string' }, Component: TextField });

/** The `multiline` component: a string edited in a text area. */
export const MULTILINE = register({ id: 'multiline', stores: { type: 'string' }, Component: MultilineField });
