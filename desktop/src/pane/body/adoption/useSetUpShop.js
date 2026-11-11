/**
 * @file Setting up shop in the selected checkout: what the adoption form
 * starts with, and the adoption in progress and how it ended.
 */

import { useCallback, useEffect, useState } from 'react';
import { approveProject } from '../../../modules/approval/approval.js';
import { client } from '../../../client/index.js';
import { LOADING, remoteOf } from '../../../remote.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';
import { adoptionOf } from './adoptionSteps.js';

/** While the user fills the form. */
const FILLING = Object.freeze({ phase: 'filling' });

/** While POST /project/adopt runs. */
const ADOPTING = Object.freeze({ phase: 'adopting' });

/** The guesses when the agent could not be asked. */
const NO_GUESS = Object.freeze({ found: false, description: '', command: '' });

/**
 * Returns `{suggested, reload, attempt, adopt}` for the checkout at `root`.
 * `suggested` is remote data holding GET /project/adoption's answer and the
 * agent's guesses from GET /project/adoption/guess as `guessed`; it
 * succeeds once both have answered, with no guess when that call failed.
 * `reload()` asks for both again. `adopt(answers)` first records the
 * user's approval of the project, which completing setup gives, then sends
 * the answers to POST /project/adopt, so a failure of either leaves nothing half
 * done that trying again does not finish. `attempt.phase` is `filling`,
 * `adopting`, or `failed` with the `error`, the `step` that failed
 * (`approval` or `adoption`) and the `answers` to try again with. When it
 * succeeds the pane reads the checkout's setup and project again.
 *
 * @param {string} root The checkout's root.
 */
export function useSetUpShop(root) {
  const { retry } = useWorkshop();
  const [suggested, setSuggested] = useState(LOADING);
  const [asked, setAsked] = useState(0);
  const [attempt, setAttempt] = useState(FILLING);
  useEffect(loadSuggestions(root, setSuggested), [root, asked]);
  const reload = useCallback(() => setAsked((before) => before + 1), []);
  const adopt = useCallback(async (answers) => {
    setAttempt(ADOPTING);
    const failure = await carriedOut(root, adoptionOf(answers));
    settle(failure, answers, setAttempt, retry);
  }, [root, retry]);

  return { suggested, reload, attempt, adopt };
}

/**
 * Loads what the adoption form starts with for the checkout, and the
 * agent's guesses, at the same time. Answers that arrive after the
 * checkout changes are dropped.
 *
 * @effect
 * @param root The checkout's root.
 * @param setSuggested Stores the answers.
 */
function loadSuggestions(root, setSuggested) {
  return () => {
    let open = true;
    setSuggested(LOADING);
    Promise.all([client.adoption(root), client.adoptionGuess(root)])
      .then(([found, guessed]) => open && setSuggested(remoteOf(withGuess(found, guessed))));
    return () => { open = false; };
  };
}

/**
 * GET /project/adoption's result with the agent's guesses added as `guessed`, no guess when that call failed.
 *
 * @param found GET /project/adoption's result.
 * @param guessed GET /project/adoption/guess's result.
 */
function withGuess(found, guessed) {
  return found.ok ? { ok: true, data: { ...found.data, guessed: guessed.ok ? guessed.data : NO_GUESS } } : found;
}

/**
 * Sets up shop in the checkout at `root`: records the user's approval of
 * it, then adopts the branch. Answers null when both went through, else
 * `{step, error}` for the first that failed, after which nothing more ran.
 *
 * @param {string} root The checkout's root.
 * @param {{manifest: Record<string, string>, commit: boolean}} adoption What the wizard's answers ask for.
 */
async function carriedOut(root, adoption) {
  const approved = await approveProject(root);
  if (!approved.ok) {
    return { step: 'approval', error: approved.error };
  }
  const adopted = await client.adopt(root, adoption.manifest, adoption.commit);
  return adopted.ok ? null : { step: 'adoption', error: adopted.error };
}

/**
 * Records how setting up shop ended: on success, asks for the setup and
 * the project again; otherwise keeps the step that failed, its error and
 * the answers.
 *
 * @param {{step: string, error: object} | null} failure What failed, or null.
 * @param {Record<string, string>} answers The wizard's answers.
 * @param setAttempt Stores the attempt.
 * @param retry Asks for a piece of the pane's state again.
 */
function settle(failure, answers, setAttempt, retry) {
  if (failure) {
    setAttempt({ phase: 'failed', ...failure, answers });
    return;
  }
  retry('setup');
  retry('project');
}
