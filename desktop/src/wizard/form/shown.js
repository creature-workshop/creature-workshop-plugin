/**
 * @file Which of a wizard's steps a form shows, and the answers it finishes
 * with: a form shows every step at once, so it follows the wizard's
 * branches from the first step with the answers as they stand.
 */

import { nextIndex } from '../flow.js';

/**
 * The indexes of the steps the form shows: the first, then each step the
 * one before it leads to with its current answer, until the wizard
 * finishes or a step comes round again.
 *
 * @param {import('../steps.js').Step[]} steps The wizard's steps.
 * @param {Record<string, string>} values Each step's current answer, by its key.
 *
 * @returns {number[]} The indexes, in the order the form shows them.
 */
export function shownSteps(steps, values) {
  const shown = [];
  let at = steps.length > 0 ? 0 : -1;
  while (at !== -1 && !shown.includes(at)) {
    shown.push(at);
    at = nextIndex(at, steps, values[steps[at].key] ?? '');
  }
  return shown;
}

/**
 * Each step's answer before the user changes any: a prompt's fallback, the
 * form's starting text, and a select's default option.
 *
 * @param {import('../steps.js').Step[]} steps The wizard's steps.
 *
 * @returns {Record<string, string>} The answers, by key; a dialog has none.
 */
export function startingValues(steps) {
  return Object.fromEntries(steps.filter((step) => step.key).map((step) => [step.key, startingValue(step)]));
}

/**
 * The answers the form finishes with: the answer of each step it shows.
 *
 * @param {import('../steps.js').Step[]} steps The wizard's steps.
 * @param {Record<string, string>} values Each step's current answer, by its key.
 *
 * @returns {Record<string, string>} The answers, by key.
 */
export function finalAnswers(steps, values) {
  const keys = shownSteps(steps, values).map((at) => steps[at].key).filter(Boolean);
  return Object.fromEntries(keys.map((key) => [key, values[key]]));
}

/**
 * A step's answer before the user changes it.
 *
 * @param {import('../steps.js').Step} step A prompt or a select.
 */
function startingValue(step) {
  return step.kind === 'select' ? step.options[step.defaultIndex].value : step.fallback ?? '';
}
