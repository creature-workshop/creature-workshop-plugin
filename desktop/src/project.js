/**
 * @file Loading the project through the backend and reading its toolchain:
 * the pure side of the pane, with no React in it.
 */

export const CHECK_EVERY_MS = 20000;

/** Loads the project for a directory through the backend and publishes it to the store. */
export async function load(rest, store, cwd, withCheck) {
  try {
    const query = `/project?path=${encodeURIComponent(cwd || '')}&check=${withCheck ? '1' : '0'}`;
    const project = await rest(query);
    store.set({ ...store.get(), ...project, error: null, at: Date.now() });
  } catch (error) {
    store.set({ ...store.get(), error: String(error && error.message ? error.message : error) });
  }
}

/** The rows of the toolchain and how many of them are installed. */
export function toolchainSummary(project) {
  const rows = project.toolchain && project.toolchain.rows ? project.toolchain.rows : [];
  const installed = rows.filter((row) => row.installed).length;
  return { rows, installed, total: rows.length };
}
