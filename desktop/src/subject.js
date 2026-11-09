/**
 * @file The pane's subject: what the pane is about, the way Unity's
 * inspector is about the object last selected. Every part of the pane takes
 * what it shows from the subject. A subject has a kind, the id of the thing
 * it names, and the folder whose repositories the pane shows. The one kind
 * is the focused chat session; Desktop's plugin SDK does not yet say what
 * else the user has selected.
 */

/** The kind of a subject that is a chat session. */
export const SESSION = 'session';

/**
 * A chat session as the pane's subject.
 *
 * @typedef {object} SessionSubject
 * @property {'session'} kind Always SESSION.
 * @property {string} id The session's durable id, the one Desktop keeps across restarts; empty when no session is focused.
 * @property {string} folder The session's working folder; empty when it is not known.
 */

/**
 * What the pane is about. Each kind of subject is one member of this union,
 * told apart by its `kind`; the chat session is the only member until
 * Desktop's plugin SDK says what else the user has selected.
 *
 * @typedef {SessionSubject} Subject
 */

/**
 * The subject for a chat session.
 *
 * @param {string | null} storedSessionId The session's durable id, or null when no session is focused.
 * @param {string | undefined} folder The session's working folder.
 *
 * @returns {SessionSubject} The subject, with an empty id and folder for what is unknown.
 */
export function sessionSubject(storedSessionId, folder) {
  return { kind: SESSION, id: storedSessionId || '', folder: folder || '' };
}
