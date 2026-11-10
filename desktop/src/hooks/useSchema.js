/**
 * @file The hook that holds the JSON Schema of a store: the document that
 * says which keys its records have and what each holds.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';

/**
 * Asks the store for the store's schema, and asks again whenever the
 * store changes. Answers null until the schema arrives, then the
 * schema, or `{}` when the store could not give one. An answer for a
 * store the pane has already moved away from is thrown away.
 *
 * @param {import('../client/store.js').Store} store The store.
 *
 * @returns {object | null} The schema.
 */
export function useSchema({ kind, root, source }) {
  const [schema, setSchema] = useState(null);
  useEffect(askSchema({ kind, root, source }, setSchema), [kind, root, source]);
  return schema;
}

/**
 * Forgets the schema shown so far, and asks for the store's.
 *
 * @effect
 * @param {import('../client/store.js').Store} store The store.
 * @param setSchema Keeps the schema.
 */
function askSchema(store, setSchema) {
  return () => {
    let open = true;
    setSchema(null);
    client.introspect(store).then((answer) => open && setSchema(answer.data?.schema ?? {}));
    return () => { open = false; };
  };
}
