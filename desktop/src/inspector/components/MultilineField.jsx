/**
 * @file The built-in `multiline` component: a string edited in a text area
 * that wraps.
 */

import { StringField } from './StringField.jsx';

/**
 * A string key edited in a text area that wraps. Enter still saves, since
 * the stores write one line.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function MultilineField(props) {
  return <StringField field={props} multiline />;
}
