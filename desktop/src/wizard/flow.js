/**
 * @file Moving through a wizard's steps, the same way for every
 * implementation of the contract: which step comes after an answer, how the
 * answers collect, and the check that every jump lands on a step.
 */

/** Where each kind of branch goes; the functions it names are below. */
const BRANCH_TARGETS = { next: following, finish: finished, jump: jumped };

/**
 * The answers with one more, under the step's key; a dialog adds none.
 *
 * @param {Record<string, string>} answers The answers so far.
 * @param {import('./steps.js').Step} step The step answered.
 * @param {string} value Its answer.
 *
 * @returns {Record<string, string>} The answers, a new object.
 */
export function record(answers, step, value) {
  return step.key ? { ...answers, [step.key]: value } : answers;
}

/**
 * The index of the step to show after the user answered `current`, or -1
 * when the wizard is finished. A step's branch sees only its own answer.
 *
 * @param {number} current The index of the step answered.
 * @param {import('./steps.js').Step[]} steps The wizard's steps.
 * @param {string} value Its answer; ignored for a dialog.
 *
 * @returns {number} The next step's index, or -1.
 */
export function nextIndex(current, steps, value) {
  const step = steps[current];
  const branch = step.branch ? step.branch(step.key ? { [step.key]: value } : {}) : { kind: 'next' };
  return BRANCH_TARGETS[branch.kind](current, steps, branch);
}

/**
 * Throws when a step's branch, asked with no answer, jumps to an id no step
 * has, or when two steps share an id, as blizz checks before it runs.
 *
 * @param {import('./steps.js').Step[]} steps The wizard's steps.
 */
export function validateTargets(steps) {
  const ids = steps.map((step) => step.id).filter(Boolean);
  const repeated = ids.find((id, at) => ids.indexOf(id) !== at);
  if (repeated) {
    throw new Error(`Two steps share the id '${repeated}'.`);
  }
  steps.forEach((step) => checkTarget(step, ids));
}

/**
 * Throws when the step's branch, asked with no answer, jumps to an id outside `ids`.
 *
 * @param {import('./steps.js').Step} step The step.
 * @param {string[]} ids Every step's id.
 */
function checkTarget(step, ids) {
  const branch = step.branch?.({});
  if (branch?.kind === 'jump' && !ids.includes(branch.id)) {
    throw new Error(`A step jumps to '${branch.id}', and no step has that id. The ids are: ${ids.join(', ')}.`);
  }
}

/**
 * The step after `current` in order, or -1 after the last.
 *
 * @param {number} current The index of the step answered.
 * @param {import('./steps.js').Step[]} steps The wizard's steps.
 */
function following(current, steps) {
  return current + 1 < steps.length ? current + 1 : -1;
}

/** -1, the end of the wizard. */
function finished() {
  return -1;
}

/**
 * The index of the step with the branch's id.
 *
 * @param {number} current The index of the step answered; unused.
 * @param {import('./steps.js').Step[]} steps The wizard's steps.
 * @param {{id: string}} branch The jump.
 */
function jumped(current, steps, branch) {
  return steps.findIndex((step) => step.id === branch.id);
}
