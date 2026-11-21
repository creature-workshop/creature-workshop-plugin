/**
 * @file The inspector: shows a binding's fields, each drawn by the component
 * the binding names, from the record and the schema of the binding's file.
 */

import './builtins.js';
import { FieldGroup } from './FieldGroup.jsx';
import { InspectorFailed } from './InspectorFailed.jsx';
import { InspectorFields } from './InspectorFields.jsx';

/**
 * Shows the binding's fields under its title, in the binding's order, for
 * the selected checkout. Keys the binding does not list are left out. The
 * fields are bound to the binding's record, so they appear once the record
 * and its schema have been read, and they follow the file from then on: a
 * change made outside the pane shows on the next read. When the record
 * could not be read, the group says so in the fields' place, with why, what
 * to try, and Try again. A record that does not exist is not a failure
 * when `missing` is given: the group shows what `missing` draws in the
 * fields' place. `missing` is given `reread`, which reads the file again,
 * for when it has made the record.
 *
 * @param props The component's props.
 * @param {object} props.binding What to show, as register in bindings.js returns it.
 * @param {(reread: () => void) => import('react').ReactNode} [props.missing] Draws what to show when the record does not exist, such as a button that creates it.
 */
export function Inspector({ binding, missing = null }) {
  return (
    <FieldGroup title={binding.title}>
      <InspectorFields
        bind={{ ...binding.file, record: binding.record }}
        binding={binding}
        failed={(error, reread) => <InspectorFailed binding={binding} missing={missing} error={error} onRetry={reread} />}
      />
    </FieldGroup>
  );
}
