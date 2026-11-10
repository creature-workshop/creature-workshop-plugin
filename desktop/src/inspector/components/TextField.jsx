/**
 * @file The built-in `text` component: a one-line string.
 */

import { StringField } from './StringField.jsx';

/**
 * A string key edited in a one-line input.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function TextField(props) {
  return <StringField field={props} multiline={false} />;
}
