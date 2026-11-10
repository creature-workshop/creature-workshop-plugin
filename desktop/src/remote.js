/**
 * @file Data the pane asks the backend for, in one of three states, as
 * Elm's RemoteData models it: loading, failure or success. A part of the
 * pane draws each state, so a failure is never drawn as if it were an
 * empty answer.
 *
 *   {state: 'loading'}
 *   {state: 'failure', error: {message, code, status, extensions}}
 *   {state: 'success', data}
 */

/** Data that has been asked for and has not arrived. */
export const LOADING = Object.freeze({ state: 'loading' });

/**
 * The remote data a call's result stands for: success with its data, or
 * failure with its error.
 *
 * @param result A result, as client/api.js answers it.
 */
export function remoteOf(result) {
  return result.ok ? { state: 'success', data: result.data } : { state: 'failure', error: result.error };
}

/**
 * The data when `remote` arrived, or `fallback` while it is loading or
 * when it failed.
 *
 * @param remote The remote data.
 * @param fallback What to use instead.
 */
export function dataOr(remote, fallback) {
  return remote.state === 'success' ? remote.data : fallback;
}
