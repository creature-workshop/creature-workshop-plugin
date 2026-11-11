/**
 * @file Keeping remote data in place when a quiet read answers the same
 * thing, so a read made on a timer redraws the pane only for a change.
 */

import { remoteOf } from '../remote.js';

/**
 * The stored remote data after a quiet read answered `data`: the same
 * object when it already holds an equal answer, else the new answer as a
 * success. Two answers are equal when they are the same JSON.
 *
 *     changed({state: 'success', data: {a: 1}}, {a: 1})  ->  the first argument itself
 *
 * @param before The stored remote data.
 * @param data What the quiet read answered.
 *
 * @returns The remote data to store.
 */
export function changed(before, data) {
  const same = before.state === 'success' && JSON.stringify(before.data) === JSON.stringify(data);
  return same ? before : remoteOf({ ok: true, data });
}
