/**
 * @file The steps of a wizard, the same configuration blizz's Step takes in
 * Rust: a dialog that only says something, a prompt for text, a select over
 * options, and a confirm that branches on yes or no. A step is plain data;
 * the `with` helpers return a copy with one more setting, as blizz's
 * builder methods do.
 */

import { FINISH, NEXT } from './branch.js';

/** The options of every confirm, in blizz's order. */
const YES_NO = Object.freeze([
  Object.freeze({ label: 'Yes', value: 'yes' }),
  Object.freeze({ label: 'No', value: 'no' }),
]);

/**
 * A step of a wizard.
 *
 * @typedef {object} Step
 * @property {'dialog' | 'prompt' | 'select'} kind What the step asks of the user.
 * @property {string} text The message of a dialog, or the question of a prompt or select.
 * @property {string} [key] The answer's name in the answers a wizard finishes with; a dialog has none.
 * @property {string} [fallback] A prompt's answer when the user enters nothing.
 * @property {boolean} [multiline] Whether a prompt's answer may run over several lines.
 * @property {{label: string, value: string}[]} [options] A select's options, in order.
 * @property {number} [defaultIndex] The option a select starts on.
 * @property {string} [id] The name a branch jumps to.
 * @property {string} [hint] A short note shown with the step, such as where its starting answer came from.
 * @property {string} [info] What the step's answer is for, shown on request, as the pane's (i) shows a field's help.
 * @property {(output: Record<string, string>) => {kind: string, id?: string}} [branch]
 *   Decides where to go from this step's own answer, `{[key]: value}`; NEXT when absent.
 */

/**
 * A step that shows a message and goes on when the user does.
 *
 * @param {string} message What to say.
 *
 * @returns {Step} The step.
 */
export function dialog(message) {
  return Object.freeze({ kind: 'dialog', text: message });
}

/**
 * A step that asks for a line of text.
 *
 * @param {string} question What to ask.
 * @param {string} key The answer's name.
 * @param {string} fallback The answer when the user enters nothing.
 *
 * @returns {Step} The step.
 */
export function prompt(question, key, fallback) {
  return Object.freeze({ kind: 'prompt', text: question, key, fallback });
}

/**
 * A step that asks the user to pick one of several options, starting on the first.
 *
 * @param {string} question What to ask.
 * @param {string} key The answer's name; the answer is the picked option's value.
 * @param {[string, string][]} options Each option as `[label, value]`, as blizz takes them.
 *
 * @returns {Step} The step.
 */
export function select(question, key, options) {
  const choices = Object.freeze(options.map(([label, value]) => Object.freeze({ label, value })));
  return Object.freeze({ kind: 'select', text: question, key, options: choices, defaultIndex: 0 });
}

/**
 * A yes-or-no select that branches on the answer.
 *
 * @param {string} question What to ask.
 * @param {string} key The answer's name; the answer is `yes` or `no`.
 * @param {{kind: string, id?: string}} onYes Where to go on yes.
 * @param {{kind: string, id?: string}} onNo Where to go on no.
 *
 * @returns {Step} The step.
 */
export function confirm(question, key, onYes = NEXT, onNo = FINISH) {
  const decide = (output) => (output[key] === 'no' ? onNo : onYes);
  return Object.freeze({ kind: 'select', text: question, key, options: YES_NO, defaultIndex: 0, branch: decide });
}

/**
 * The step with an id a branch can jump to.
 *
 * @param {Step} step The step.
 * @param {string} id Its id, unique among the wizard's steps.
 *
 * @returns {Step} A copy of the step with the id.
 */
export function withId(step, id) {
  return Object.freeze({ ...step, id });
}

/**
 * Whether the step is a confirm: a select over exactly Yes and No.
 *
 * @param {Step} step The step.
 */
export function isConfirm(step) {
  return step.kind === 'select' && step.options === YES_NO;
}

/**
 * The step with a short note shown with it, as blizz's hint line: where
 * its starting answer came from, or what to enter.
 *
 * @param {Step} step The step.
 * @param {string} hint The note.
 *
 * @returns {Step} A copy of the step with the hint.
 */
export function withHint(step, hint) {
  return Object.freeze({ ...step, hint });
}

/**
 * The step with help on what its answer is for, which an implementation
 * shows when the user asks, as the pane's (i) after a field's name does.
 *
 * @param {Step} step The step.
 * @param {string} info The help.
 *
 * @returns {Step} A copy of the step with the help.
 */
export function withInfo(step, info) {
  return Object.freeze({ ...step, info });
}

/**
 * The prompt taking an answer of several lines, which an implementation
 * shows in a taller field that wraps; any other step unchanged.
 *
 * @param {Step} step The step.
 *
 * @returns {Step} A copy of the prompt that takes several lines.
 */
export function withLines(step) {
  return step.kind === 'prompt' ? Object.freeze({ ...step, multiline: true }) : step;
}

/**
 * The select starting on another option; any other step unchanged.
 *
 * @param {Step} step The step.
 * @param {number} index The option to start on.
 *
 * @returns {Step} A copy of the select with the default.
 */
export function withDefaultIndex(step, index) {
  return step.kind === 'select' ? Object.freeze({ ...step, defaultIndex: index }) : step;
}

/**
 * The step deciding where to go from its own answer.
 *
 * @param {Step} step The step.
 * @param {(output: Record<string, string>) => {kind: string, id?: string}} decide
 *   Takes `{[key]: value}` for the step's answer and returns a branch.
 *
 * @returns {Step} A copy of the step with the decision.
 */
export function onSubmit(step, decide) {
  return Object.freeze({ ...step, branch: decide });
}
