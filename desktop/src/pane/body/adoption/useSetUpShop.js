/**
 * @file Setting up shop in the selected checkout: what the adoption form
 * starts with, and the adoption in progress and how it ended.
 */

import { useCallback, useEffect, useState } from 'react';
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
 * `reload()` asks for both again. `adopt(answers)` sends the wizard's answers
 * to POST /project/adopt; `attempt.phase` is `filling`, `adopting`, or
 * `failed` with the `error` and the `answers` to try again with. When it
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
    const { manifest, commit } = adoptionOf(answers);
    settle(await client.adopt(root, manifest, commit), answers, setAttempt, retry);
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
 * Records how the adoption ended: on success, asks for the setup and the
 * project again; otherwise keeps the error and the answers.
 *
 * @param result POST /project/adopt's result.
 * @param {Record<string, string>} answers The wizard's answers.
 * @param setAttempt Stores the attempt.
 * @param retry Asks for a piece of the pane's state again.
 */
function settle(result, answers, setAttempt, retry) {
  if (!result.ok) {
    setAttempt({ phase: 'failed', error: result.error, answers });
    return;
  }
  retry('setup');
  retry('project');
}
