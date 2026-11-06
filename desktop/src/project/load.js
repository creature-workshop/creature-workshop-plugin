/**
 * @file Loading the project through the backend: a plain function with no
 * React in it. WorkshopPane's effects call load, which asks the backend and publishes
 * the answer to the store; the hook that reads the store back is useProject
 * in store.js.
 */

/**
 * Loads the project for a directory through the backend and publishes it to the store.
 * @param rest The backend call, taking a path under the plugin's API.
 * @param store The store the pane and the chip share.
 * @param cwd The session's directory.
 * @param withCheck Whether the backend runs install --check for the toolchain.
 */
export async function load(rest, store, cwd, withCheck) {
  try {
    const query = `/project?path=${encodeURIComponent(cwd || '')}&check=${withCheck ? '1' : '0'}`;
    const project = await rest(query);
    store.set({ ...store.get(), ...project, error: null, at: Date.now() });
  } catch (error) {
    store.set({ ...store.get(), error: String(error && error.message ? error.message : error) });
  }
}
