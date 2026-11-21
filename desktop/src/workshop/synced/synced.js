/**
 * @file The pane's copy of one checkout's files, kept current by reading
 * them again, and the one place a write to them goes through.
 *
 * The checkout's files are the truth. For each file a part of the pane
 * follows, this module keeps the snapshot the last read answered, and `read`
 * reads every followed file again, through the `sync` it is given, which
 * read.js fills. Each file is its own piece: an answer for one file
 * calls only that file's listeners, and only when the snapshot differs from
 * the one answered before.
 *
 * A write joins one queue for the whole checkout and is sent alone, at the
 * revision its record has when it is sent. Until the backend answers it,
 * the write is in flight, and the file's view shows it applied on top of
 * the snapshot, as view.js describes. The backend's answer replaces the
 * record in the snapshot and the write leaves the queue. A write the backend
 * refuses leaves the queue too, so the view goes back to what the snapshot
 * holds, and the write resolves to why.
 *
 * An answer to a read that was asked for before the backend confirmed a
 * write is dropped, since it may describe the files as they were before
 * that write.
 */

import { keyOf } from './address.js';
import { afterWrite, revisionOf } from './opsFileSnapshot.js';
import { viewOf } from './view.js';
import { failureMessage, STALE_MESSAGE } from './writeMessage.js';

/**
 * The synced files of the checkout at `root`. Returns:
 *
 * - `follow(file, listen)`, which calls `listen` whenever the file's view
 *   changes, reads the followed files when the file gains its first
 *   listener, and returns what stops the listening;
 * - `view(file)`, the file's view as view.js describes it, the same
 *   object until it changes;
 * - `write(file, operation)`, which queues one operation, as
 *   client/store.js describes an Operation without its revision, and
 *   resolves to null once the backend kept it, to STALE_MESSAGE when the
 *   record changed outside the pane, or to why the backend refused it;
 * - `read()`, which reads every followed file again and resolves when the
 *   answer has been kept;
 * - `every(seconds)`, which reads on that interval until the function it
 *   returns is called.
 *
 * @param options What the synced files read and write through.
 * @param {string} options.root The checkout's root folder.
 * @param {(root: string, files: import('./address.js').OpsFile[]) => Promise<object>} options.sync Reads the files named into snapshots, as readFiles in read.js does.
 * @param {(file: import('./address.js').OpsFile, operation: object) => Promise<object>} options.mutate The client's mutate call.
 */
export function create({ root, sync, mutate }) {
  const state = { root, sync, mutate, pieces: new Map(), writes: [], sending: false, confirmed: 0, reading: null, again: false };
  return {
    follow: (file, listen) => follow(state, file, listen),
    view: (file) => view(state, file),
    write: (file, operation) => write(state, file, operation),
    read: () => read(state),
    every: (seconds) => every(state, seconds),
  };
}

/**
 * The piece kept for a file, made on first use: the file, the snapshot the
 * last sync answered, that answer as JSON for telling the next one from
 * it, why the sync failed before any answer, the file's listeners, and
 * its view while that is current.
 *
 * @param state The synced files' state.
 * @param {import('./address.js').OpsFile} file The file.
 */
function pieceOf(state, { kind, source }) {
  const key = keyOf({ kind, source });
  if (!state.pieces.has(key)) {
    state.pieces.set(key, { file: { kind, source }, snapshot: null, answered: '', failure: null, listeners: new Set(), view: null });
  }
  return state.pieces.get(key);
}

/**
 * Adds a listener to a file, reads the followed files when it is the
 * file's first, and returns what removes the listener.
 *
 * @param state The synced files' state.
 * @param {import('./address.js').OpsFile} file The file to follow.
 * @param {() => void} listen What to call when the file's view changes.
 */
function follow(state, file, listen) {
  const piece = pieceOf(state, file);
  const first = piece.listeners.size === 0;
  piece.listeners.add(listen);
  if (first) {
    read(state);
  }
  return () => piece.listeners.delete(listen);
}

/**
 * The file's view, computed when it is first asked for after a change and
 * kept until the next one.
 *
 * @param state The synced files' state.
 * @param {import('./address.js').OpsFile} file The file.
 */
function view(state, file) {
  const piece = pieceOf(state, file);
  if (!piece.view) {
    const operations = state.writes.filter((each) => each.piece === piece).map((each) => each.operation);
    piece.view = viewOf(piece.snapshot, piece.failure, operations);
  }
  return piece.view;
}

/**
 * Forgets the piece's view and tells its listeners it changed.
 *
 * @param piece The piece that changed.
 */
function changed(piece) {
  piece.view = null;
  for (const listen of [...piece.listeners]) {
    listen();
  }
}

/**
 * Queues one operation on a file and starts sending the queue. The
 * file's view shows the operation at once.
 *
 * @param state The synced files' state.
 * @param {import('./address.js').OpsFile} file The file to write to.
 * @param {object} operation The operation, without its revision.
 *
 * @returns {Promise<string | null>} Null once the backend kept the write, or what to tell the user.
 */
function write(state, file, operation) {
  const piece = pieceOf(state, file);
  return new Promise((resolve) => {
    state.writes.push({ piece, operation, resolve });
    changed(piece);
    send(state);
  });
}

/**
 * Sends the oldest write in the queue, unless one is already being sent,
 * and then the next, until the queue is empty. A write stays in the queue
 * while it is sent, so the view keeps showing it. Once the queue is empty
 * the followed files are read again, for their state after the writes.
 *
 * @param state The synced files' state.
 */
async function send(state) {
  if (state.sending || state.writes.length === 0) {
    return;
  }
  state.sending = true;
  const [oldest] = state.writes;
  const message = await sent(state, oldest);
  state.writes.shift();
  state.sending = false;
  changed(oldest.piece);
  oldest.resolve(message);
  if (state.writes.length === 0) {
    read(state);
    return;
  }
  send(state);
}

/**
 * Sends one write at the revision its record has now, keeps what the
 * backend answered, and resolves to what the write resolves to.
 *
 * @param state The synced files' state.
 * @param queued The queued write.
 * @param queued.piece The piece of the file it writes to.
 * @param queued.operation The operation, without its revision.
 */
async function sent(state, { piece, operation }) {
  const revision = revisionOf(piece.snapshot, operation.id);
  const result = await state.mutate({ ...piece.file, root: state.root }, { ...operation, revision });
  return kept(state, piece, result);
}

/**
 * Keeps a write's answer: the record the backend answered, or, for a stale
 * write, the record as the file has it now. Returns what the write
 * resolves to.
 *
 * @param state The synced files' state.
 * @param piece The piece of the file written to.
 * @param result The mutate call's result.
 */
function kept(state, piece, result) {
  if (result.ok) {
    confirm(state, piece, result.data);
    return null;
  }
  if (result.error.code !== 'STALE') {
    return failureMessage(result.error);
  }
  confirm(state, piece, { record: result.error.extensions.record });
  return STALE_MESSAGE;
}

/**
 * Puts what the backend answered a write into the piece's snapshot, and counts
 * the answer as confirmed, since the snapshot now holds something newer than
 * any read asked for before it. The snapshot no longer matches the last
 * sync's answer, so that answer is forgotten and the next one is kept
 * whatever it says.
 *
 * @param state The synced files' state.
 * @param piece The piece of the file written to.
 * @param {{record?: object, deleted?: {id: string}}} data What the backend answered.
 */
function confirm(state, piece, data) {
  piece.snapshot = afterWrite(piece.snapshot, data);
  piece.answered = '';
  state.confirmed += 1;
}

/**
 * Reads every followed file again. While a read is under way it asks for
 * one more after it, so a file followed in the meantime is read too, and
 * returns the read under way.
 *
 * @param state The synced files' state.
 */
function read(state) {
  if (state.reading) {
    state.again = true;
    return state.reading;
  }
  state.reading = answered(state).finally(() => finished(state));
  return state.reading;
}

/**
 * Marks the read as over, and starts the one asked for while it ran.
 *
 * @param state The synced files' state.
 */
function finished(state) {
  state.reading = null;
  if (state.again) {
    state.again = false;
    read(state);
  }
}

/**
 * Asks the backend for every followed file, and keeps the answer. Asks
 * for nothing while no file is followed or a write is in flight, since
 * the queue reads again when it empties. Drops the answer when a write was
 * confirmed after the read was asked for.
 *
 * @param state The synced files' state.
 */
async function answered(state) {
  const followed = [...state.pieces.values()].filter((piece) => piece.listeners.size > 0);
  if (followed.length === 0 || state.writes.length > 0) {
    return;
  }
  const confirmed = state.confirmed;
  const result = await state.sync(state.root, followed.map((piece) => piece.file));
  if (confirmed !== state.confirmed) {
    return;
  }
  if (!result.ok) {
    followed.forEach((piece) => failed(piece, result.error));
    return;
  }
  result.data.files.forEach((snapshot) => keep(state, snapshot));
}

/**
 * Keeps why the read failed for a piece that has no snapshot yet. A piece
 * that has one keeps showing it.
 *
 * @param piece The piece.
 * @param error Why the read failed, as client/api.js flattens it.
 */
function failed(piece, error) {
  if (piece.snapshot) {
    return;
  }
  piece.failure = error;
  changed(piece);
}

/**
 * Keeps one answered snapshot in its piece, unless it is the same as the
 * snapshot the last sync answered. Two snapshots are the same when they are the
 * same JSON.
 *
 * @param state The synced files' state.
 * @param {import('./opsFileSnapshot.js').OpsFileSnapshot} snapshot The answered snapshot.
 */
function keep(state, snapshot) {
  const piece = state.pieces.get(keyOf(snapshot));
  const answered = JSON.stringify(snapshot);
  if (!piece || piece.answered === answered) {
    return;
  }
  piece.snapshot = snapshot;
  piece.answered = answered;
  piece.failure = null;
  changed(piece);
}

/**
 * Reads the followed files every `seconds`, until the returned function is
 * called.
 *
 * @param state The synced files' state.
 * @param {number} seconds How long to wait between reads.
 */
function every(state, seconds) {
  const timer = setInterval(() => read(state), seconds * 1000);
  return () => clearInterval(timer);
}
