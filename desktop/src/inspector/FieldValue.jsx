/**
 * @file An inspector field's value as text, in each of the three states.
 */

import { cn } from '@hermes/plugin-sdk';
import { stateText } from './stateText.js';

/**
 * Shows the value by its state:
 *
 * - untouched: "Not set" in the tertiary text color, with the schema's
 *   default when there is one;
 * - cleared: "Cleared", in italics;
 * - set: the text, or "Empty" in italics for an empty string.
 *
 * @param props The component's props.
 * @param {string} props.text The value as text.
 * @param {'untouched' | 'cleared' | 'set'} props.state The key's state.
 * @param {string} [props.fallback] The schema's default as text, or empty.
 */
export function FieldValue({ text, state, fallback = '' }) {
  const shown = shownText(text, state, fallback);
  const muted = shown !== text || state !== 'set';
  return (
    <span
      className={cn(
        'workshop-field-text',
        muted && 'text-(--ui-text-tertiary)',
        muted && state !== 'untouched' && 'italic',
      )}
    >
      {shown}
    </span>
  );
}

/**
 * What the field shows for its value in its state.
 *
 * @param {string} text The value as text.
 * @param {'untouched' | 'cleared' | 'set'} state The key's state.
 * @param {string} fallback The schema's default as text, or empty.
 */
function shownText(text, state, fallback) {
  if (state !== 'set') {
    return stateText(state, fallback);
  }
  return text === '' ? 'Empty' : text;
}
