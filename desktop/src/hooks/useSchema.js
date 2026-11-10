/**
 * @file The hook that holds the JSON Schema of a store: the document that
 * says which keys its records have and what each holds.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING } from '../remote.js';

/**
 * Asks the store for its schema, and asks again whenever the store or
 * `attempt` changes. Answers the schema as remote data, as
 * remote.js describes; once it succeeds, its data is the schema. An
 * answer for a store the pane has already moved away from is thrown away.
 *
 * @param {import('../client/store.js').Store} store The store.
 * @param {number} [attempt] How many times the caller has asked again; raising it asks again.
 *
 * @returns {object} The schema, as remote data.
 */
export function useSchema({ kind, root, source }, attempt = 0) {
  const [schema, setSchema] = useState(LOADING);
  useEffect(askSchema({ kind, root, source }, setSchema), [kind, root, source, attempt]);
  return schema;
}

/**
 * Asks for the store's schema, loading again in place of the one before.
 *
 * @effect
 * @param {import('../client/store.js').Store} store The store.
 * @param setSchema Keeps the schema, as remote data.
 */
function askSchema(store, setSchema) {
  return () => {
    let open = true;
    setSchema(LOADING);
    client.introspect(store).then((result) => open && setSchema(schemaOf(result)));
    return () => { open = false; };
  };
}

/**
 * The remote schema an introspection's result stands for: its schema on
 * success, `{}` when it named none, and the failure otherwise.
 *
 * @param result The introspection's result.
 */
function schemaOf(result) {
  return result.ok ? { state: 'success', data: result.data.schema ?? {} } : { state: 'failure', error: result.error };
}
