/**
 * @file Recording the user's approval of a project: adding its root to the
 * plugin's approved_projects setting, the one way a project is approved.
 *
 * The setting is written through Hermes's own settings call, the one
 * behind Settings → Plugins in Desktop (`plugins.manage` with the action
 * `settings`), and never through the plugin's backend, which has no route
 * that changes it. `requestWith` names how that call reaches Hermes, once
 * for the pane's whole life: Desktop's `host.request` in the plugin, and a
 * stand-in in a story or a test. Until it is called, nothing can be
 * recorded, and `approveProject` answers a failure that says so.
 */

import { PLUGIN_ID } from '../../events.js';

/** The setting that lists the roots of the approved projects. */
export const APPROVED_PROJECTS = 'approved_projects';

/** The code of the failure when the approval could not be recorded. */
export const NOT_RECORDED = 'APPROVAL_NOT_RECORDED';

/** The parameters of `plugins.manage` that ask for every plugin with its settings. */
const LIST_PLUGINS = Object.freeze({ action: 'list' });

/** How the pane calls Hermes, until requestWith names another way: it cannot. */
let request = () => Promise.reject(new Error('this pane has no way to change Hermes\'s settings'));

/**
 * Names how the pane calls Hermes's gateway from now on.
 *
 * @param call Takes a method's name and its parameters, and returns a promise of its answer.
 */
export function requestWith(call) {
  request = call;
}

/**
 * Adds the project at `root` to the approved_projects setting, keeping the
 * roots it already lists, and writes nothing when it lists `root` already.
 * Answers a result and never throws: `{ok: true, data: {listed}}` with the
 * roots listed afterwards, or `{ok: false, error}` with why the setting was
 * not saved.
 *
 *     await approveProject('/home/someone/notes')  ->  {ok: true, data: {listed: ['/home/someone/notes']}}
 *
 * @param {string} root The project's root.
 */
export async function approveProject(root) {
  try {
    const listed = approvedIn(await request('plugins.manage', LIST_PLUGINS));
    const after = listed.includes(root) ? listed : await saved(withRoot(listed, root));
    return { ok: true, data: { listed: after } };
  } catch (error) {
    return { ok: false, error: notRecorded(error) };
  }
}

/**
 * The roots the approved_projects setting lists, read from the answer of
 * `plugins.manage` with the action `list`: the value of that field in this
 * plugin's row; none when the row, the field or a list is missing.
 *
 * @param answer The answer, `{plugins: [{key, settings_schema: [{key, value}]}]}`.
 *
 * @returns {string[]} The roots.
 */
export function approvedIn(answer) {
  const row = (answer?.plugins ?? []).find((plugin) => plugin.key === PLUGIN_ID);
  const field = (row?.settings_schema ?? []).find((setting) => setting.key === APPROVED_PROJECTS);
  return Array.isArray(field?.value) ? field.value.filter((entry) => typeof entry === 'string') : [];
}

/**
 * The roots with `root` added at the end.
 *
 * @param {string[]} listed The roots listed now.
 * @param {string} root The root to add.
 */
export function withRoot(listed, root) {
  return [...listed, root];
}

/**
 * Writes `listed` as the approved_projects setting, and answers it.
 *
 * @param {string[]} listed The roots to list.
 */
async function saved(listed) {
  const write = {
    action: 'settings',
    key: PLUGIN_ID,
    values: { [APPROVED_PROJECTS]: listed },
  };
  await request('plugins.manage', write);
  return listed;
}

/**
 * The failure the pane shows when the setting was not saved, in the shape
 * client/api.js gives a failed call.
 *
 * @param error What the call to Hermes threw.
 */
function notRecorded(error) {
  const failure = {
    code: NOT_RECORDED,
    status: 0,
    message: `Hermes didn't save the approved_projects setting: ${error?.message ?? error}`,
  };
  return failure;
}
