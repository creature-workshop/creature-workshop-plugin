/**
 * @file Loading the project through the backend and reading its toolchain:
 * the pure side of the pane, with no React in it.
 */

/** The interval the pane refreshes on until the backend's first answer names one. */
export const REFRESH_UNTIL_ANSWERED_MS = 20000;

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

/**
 * The refresh interval in milliseconds: the backend's pane_refresh_seconds, once it has answered.
 * @param project The loaded project.
 */
export function refreshMs(project) {
  return typeof project.refresh_seconds === 'number' ? project.refresh_seconds * 1000 : REFRESH_UNTIL_ANSWERED_MS;
}

/**
 * The rows of the toolchain and how many of them are installed.
 * @param project The loaded project.
 */
export function toolchainSummary(project) {
  const rows = project.toolchain && project.toolchain.rows ? project.toolchain.rows : [];
  const installed = rows.filter((row) => row.installed).length;
  return { rows, installed, total: rows.length };
}
