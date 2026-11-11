/**
 * @file Which of a project's declared tools are installed right now, read
 * when the Dependencies tab opens.
 */

import { useCallback, useEffect, useState } from 'react';
import { client } from '../../client/index.js';
import { LOADING } from '../../remote.js';

/**
 * Returns `{check, recheck}` for the project at `root`. `check` is remote
 * data holding the `toolchain` of GET /project with its check, which runs
 * `ops install --check` in the project: loading while it runs, then its
 * rows, or null when the backend ran no check. The check runs again when
 * the tools the project declares change, and `recheck()` runs it again.
 *
 * @param {string} root The project's root.
 * @param {{channel: string, tool: string, version: string}[]} declared The tools the project declares.
 */
export function useToolchain(root, declared) {
  const [check, setCheck] = useState(LOADING);
  const [asked, setAsked] = useState(0);
  const tools = JSON.stringify(declared);
  useEffect(runCheck(root, setCheck), [root, asked, tools]);
  const recheck = useCallback(() => setAsked((before) => before + 1), []);

  return { check, recheck };
}

/**
 * Asks GET /project for the project with its toolchain check, and stores
 * the toolchain. An answer that arrives after the project changes is
 * dropped.
 *
 * @effect
 * @param root The project's root.
 * @param setCheck Stores the check.
 */
function runCheck(root, setCheck) {
  return () => {
    let open = true;
    setCheck(LOADING);
    client.project(root, true).then((result) => open && setCheck(toolchainOf(result)));
    return () => { open = false; };
  };
}

/**
 * The toolchain in GET /project's result, as remote data: its failure, or
 * success holding the toolchain, null when the answer has none.
 *
 * @param result The result, as client/api.js answers it.
 */
function toolchainOf(result) {
  return result.ok ? { state: 'success', data: result.data.toolchain ?? null } : { state: 'failure', error: result.error };
}
