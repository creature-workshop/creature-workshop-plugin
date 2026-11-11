/**
 * @file The adoption wizard's steps: what goes in a branch's first
 * .ops/config/manifest.yaml, and whether to commit it.
 */

import { NEXT } from '../../../wizard/branch.js';
import { confirm, prompt, withDefaultIndex, withHint, withInfo } from '../../../wizard/steps.js';

/** The hint on a field the agent filled in. */
const AGENT_HINT = 'Model suggestion';

/** What each field is for, in its (i), by its key. */
const INFO = Object.freeze({
  name: "The project's name, as people read it.",
  description: 'One sentence on what the project is for. Agents read it to send work to the right project.',
  'command-name': 'The command-line program the project ships. Leave it empty if it ships none.',
  org: 'The organization or group that owns the repository, such as creature-workshop.',
  repo: "The repository's name on its forge.",
  commit: "Commit the manifest and starting workshop configs to your project. Other files remain staged. Leave unchecked if you'd like to inspect the diff.",
});

/**
 * The steps of the adoption wizard: the five manifest fields, each
 * starting on what was found, and whether to commit, starting off; each
 * with what it is for in its (i). The
 * name and the repository come from the folder and its remote, and the
 * organization starts empty; the description and the command are the
 * agent's guesses, marked as such, and start empty when it has none.
 *
 * @param {{name: string, repo: string, branch: string}} suggested GET /project/adoption's answer.
 * @param {{found: boolean, description: string, command: string}} guessed GET /project/adoption/guess's answer.
 *
 * @returns {import('../../../wizard/steps.js').Step[]} The steps.
 */
export function adoptionSteps(suggested, guessed) {
  const steps = [
    prompt('Project Name', 'name', suggested.name),
    guessedPrompt(prompt('Description', 'description', guessed.description), guessed.description, AGENT_HINT),
    guessedPrompt(prompt('Command', 'command-name', guessed.command), guessed.command, AGENT_HINT),
    prompt('Organization', 'org', ''),
    prompt('Repository', 'repo', suggested.repo),
    withDefaultIndex(confirm(commitQuestion(suggested.branch), 'commit', NEXT, NEXT), 1),
  ];
  return steps.map((step) => withInfo(step, INFO[step.key]));
}

/**
 * The prompt, with `hint` when the agent guessed a value for it.
 *
 * @param {import('../../../wizard/steps.js').Step} step The prompt.
 * @param {string} guess The agent's guess, or empty.
 * @param {string} hint What to say about the guess.
 */
function guessedPrompt(step, guess, hint) {
  return guess ? withHint(step, hint) : step;
}

/**
 * The commit question, naming the branch when the checkout is on one.
 *
 * @param {string} branch The checkout's branch, or empty when detached.
 */
function commitQuestion(branch) {
  return branch ? `Commit the workshop files to ${branch}` : 'Commit the workshop files';
}

/**
 * The manifest and the commit choice in the wizard's answers.
 *
 * @param {Record<string, string>} answers The answers, by key.
 *
 * @returns {{manifest: Record<string, string>, commit: boolean}} What POST /project/adopt takes.
 */
export function adoptionOf(answers) {
  const { commit, ...manifest } = answers;
  return { manifest, commit: commit === 'yes' };
}
