/**
 * @file The Report it button under a failure that is a bug in the
 * Workshop plugin.
 */

import { Button } from '@hermes/plugin-sdk';
import { reportLink } from './report.js';

/**
 * A small "Report it" button that opens a new email to the intake address,
 * with `what` as its subject and `details` in its body. Desktop hands a
 * mailto link to the system's mail program.
 *
 * @param props The component's props.
 * @param {string} props.what What went wrong.
 * @param {string} props.details The debugging information.
 */
export function ReportLink({ what, details }) {
  return (
    <Button size="xs" asChild>
      <a href={reportLink(what, details)}>Report it</a>
    </Button>
  );
}
