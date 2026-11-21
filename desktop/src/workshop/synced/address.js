/**
 * @file The files of a checkout that the pane reads and writes, and how the
 * pane's synced copy addresses one: the name it keeps the file under, and
 * where the file is in the checkout.
 */

/**
 * One YAML file under the checkout's .ops/ folder, which the backend reads
 * as a list of records. `source` is the file's path under .ops/, and `kind`
 * says how the backend reads the file as records.
 *
 * - `{kind: 'document', source: 'config/manifest.yaml'}` is
 *   `.ops/config/manifest.yaml`, read as one record with the id `document`.
 * - `{kind: 'plan', source: 'data/plan.yaml'}` is `.ops/data/plan.yaml`,
 *   read as one record for each ticket in it.
 *
 * The backend's routes for these files are under /file, and
 * client/file.js calls them.
 *
 * @typedef {object} OpsFile
 * @property {string} kind `document` or `plan`.
 * @property {string} source The file's path under .ops/, such as `config/manifest.yaml`.
 */

/**
 * The key of a file: its kind and its source, joined.
 *
 *     keyOf({kind: 'document', source: 'config/manifest.yaml'})  ->  'document:config/manifest.yaml'
 *
 * @param {OpsFile} file The file.
 */
export function keyOf({ kind, source }) {
  return `${kind}:${source}`;
}

/**
 * The path of a file in the checkout, from its source.
 *
 *     pathOf('/home/someone/notes', 'config/manifest.yaml')  ->  '/home/someone/notes/.ops/config/manifest.yaml'
 *
 * @param {string} root The checkout's root folder.
 * @param {string} source The file's source.
 */
export function pathOf(root, source) {
  return `${root}/.ops/${source}`;
}
