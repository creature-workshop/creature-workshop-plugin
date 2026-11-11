/**
 * @file Asking the model why the project has one dependency: the question
 * in progress and how it ended.
 */

import { useCallback, useState } from 'react';
import { client } from '../../client/index.js';
import { detailsOf } from '../../failures/describe.js';

/** Before the user asks. */
const IDLE = Object.freeze({ phase: 'idle' });

/** While the model is asked. */
const ASKING = Object.freeze({ phase: 'asking' });

/**
 * Returns `{explanation, ask}` for the tool named `tool` in the project at
 * `root`. `ask()` asks GET /project/dependencies/explain. `explanation.phase`
 * is `idle`, `asking`, `explained` with the `text` and the `model` that
 * gave it, or `failed` with the
 * `details` of why, when the call failed or the model gave no explanation.
 *
 * @param {string} root The project's root.
 * @param {string} tool The tool's name.
 */
export function useExplanation(root, tool) {
  const [explanation, setExplanation] = useState(IDLE);
  const ask = useCallback(async () => {
    setExplanation(ASKING);
    setExplanation(explanationOf(await client.explainDependency(root, tool)));
  }, [root, tool]);

  return { explanation, ask };
}

/**
 * How the question ended, from GET /project/dependencies/explain's result:
 * explained with the text and the model that gave it; or failed with the details of why, which are
 * the error's when the call itself failed, and the backend's reason when
 * the model gave no explanation.
 *
 *     explanationOf({ok: true, data: {found: false, reason: 'Error code: 400'}})
 *       ->  {phase: 'failed', details: 'Error code: 400'}
 *
 * @param result The result, as client/api.js answers it.
 *
 * @returns {{phase: string, text?: string, model?: string, details?: string}} The explanation's state.
 */
export function explanationOf(result) {
  if (!result.ok) {
    return { phase: 'failed', details: detailsOf(result.error) };
  }
  return result.data.found
    ? { phase: 'explained', text: result.data.explanation, model: result.data.model ?? '' }
    : { phase: 'failed', details: result.data.reason };
}
