/**
 * @file What an inspector group shows in place of its fields when the
 * binding's record could not be read.
 */

import { FailureNotice } from '../failures/FailureNotice.jsx';

/**
 * What `missing` draws when the record does not exist and `missing` is
 * given. Otherwise a notice that says the binding's fields could not be
 * read from its file, with why, what to try, and Try again.
 *
 * @param props The component's props.
 * @param {object} props.binding What the group shows, as register in bindings.js returns it.
 * @param {((reread: () => void) => import('react').ReactNode) | null} props.missing Draws what to show when the record does not exist, or null.
 * @param props.error Why the record could not be read, as client/api.js flattens an error.
 * @param {() => void} props.onRetry Reads the file again.
 */
export function InspectorFailed({ binding, missing, error, onRetry }) {
  if (missing && error.code === 'NOT_FOUND') {
    return missing(onRetry);
  }

  return <FailureNotice what={`I couldn't read the ${binding.title} fields from ${binding.store.source}.`} error={error} onRetry={onRetry} />;
}
