/**
 * @file Which implementation of the wizard contract the pane runs. An
 * implementation is a React component that takes WizardProps, shows the
 * steps one at a time in its own way, and calls onFinish with the answers.
 * plugin.jsx registers one at start; the rest of the plugin only ever
 * renders Wizard, so an implementation can be replaced without touching it.
 */

/**
 * What an implementation of the contract is given.
 *
 * @typedef {object} WizardProps
 * @property {string} tool The name of what is being set up, as blizz's create_wizard takes it.
 * @property {import('./steps.js').Step[]} steps The steps, already checked with validateTargets.
 * @property {(answers: Record<string, string>) => void} onFinish Called once, with every answer by its key.
 * @property {() => void} onCancel Called when the user leaves the wizard before it finishes.
 */

/** The registered implementation; null until one is registered. */
let current = null;

/**
 * Makes `component` the implementation every Wizard renders, replacing any before it.
 *
 * @param {(props: WizardProps) => unknown} component The implementation.
 */
export function register(component) {
  current = component;
}

/**
 * The registered implementation, or null when none is.
 *
 * @returns {((props: WizardProps) => unknown) | null} The implementation.
 */
export function registered() {
  return current;
}
