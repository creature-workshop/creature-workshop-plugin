/**
 * @file Where the user reports a bug in the Workshop plugin: an email to
 * the intake address, which files it as a request.
 */

/** The address that takes bug reports and requests. */
export const REPORT_ADDRESS = 'requests@creature-workshop.com';

/** The sentence that asks the user to report a bug. */
export const REPORT_INVITE = `Let us know about your issue at ${REPORT_ADDRESS} and we'll look into it.`;

/**
 * A mailto link to REPORT_ADDRESS whose subject is `what` and whose body
 * holds `details`, ready for the user to add what they were doing.
 *
 * @param {string} what What went wrong, such as "The footer stopped working.".
 * @param {string} details The debugging information.
 */
export function reportLink(what, details) {
  const body = `What I was doing:\n\n\nDetails:\n${details}\n`;
  return `mailto:${REPORT_ADDRESS}?subject=${encodeURIComponent(`Workshop plugin: ${what}`)}&body=${encodeURIComponent(body)}`;
}
