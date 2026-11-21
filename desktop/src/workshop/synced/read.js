/**
 * @file One read of a checkout's files from the backend. For each file it
 * asks GET /store/query for the records, GET /store/introspect for the
 * schema and GET /repos/file-state for the state of the file in git, and
 * opsFileSnapshot.js makes the three answers one OpsFileSnapshot. The read
 * fails as a whole when the backend did not answer one of the calls.
 */

import { pathOf } from './address.js';
import { snapshotFrom } from './opsFileSnapshot.js';

/** The codes of a call the backend never answered. */
const UNANSWERED = Object.freeze(['UNREACHABLE', 'NO_ROUTE']);

/**
 * Reads every file asked for, and resolves to a result, as client/api.js
 * describes one. It is ok with `{files}`, one OpsFileSnapshot for each file in the
 * order asked, when the backend answered every call. When the backend did
 * not answer a call at all, the result is that call's failure, since
 * nothing was learned about the files.
 *
 * @param client The backend's client: its `query`, `introspect` and `fileState` calls.
 * @param {string} root The checkout's root folder.
 * @param {import('./address.js').OpsFile[]} files The files to read.
 */
export async function readFiles(client, root, files) {
  const read = await Promise.all(files.map((file) => readFile(client, root, file)));
  const unanswered = read.find((each) => !each.ok);
  return unanswered ?? { ok: true, data: { files: read.map((each) => each.data) } };
}

/**
 * Reads one file: a result that is ok with its OpsFileSnapshot, or the failure of a
 * call the backend never answered.
 *
 * @param client The backend's client.
 * @param {string} root The checkout's root folder.
 * @param {import('./address.js').OpsFile} file The file to read.
 */
async function readFile(client, root, { kind, source }) {
  const asked = { kind, root, source };
  const [queried, described, state] = await Promise.all([client.query(asked), client.introspect(asked), client.fileState(root, pathOf(root, source))]);
  const unanswered = [queried, described, state].find(isUnanswered);
  if (unanswered) {
    return unanswered;
  }
  return { ok: true, data: snapshotFrom({ kind, source }, { queried, described, state }) };
}

/**
 * Whether a call's result is the failure of a call the backend never answered.
 *
 * @param result A result, as client/api.js answers it.
 */
function isUnanswered(result) {
  return !result.ok && UNANSWERED.includes(result.error.code);
}
