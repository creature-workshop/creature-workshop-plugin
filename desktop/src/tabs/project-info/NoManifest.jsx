/**
 * @file What the Manifest group shows for a project that has no
 * .ops/config/manifest.yaml: that it has none, and a button that opens the
 * form that writes one.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { SetUpShop } from '../../pane/body/adoption/SetUpShop.jsx';
import { folderName } from '../../repos/folderName.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';

/** What the group says about a project with no manifest. */
const WHY = "The manifest says what the project is: its name, description, command, organization and repository. I can fill most of it in for you.";

/**
 * A status saying the selected project has no manifest yet and what one
 * is for, with a Create manifest button. The button opens the form
 * Initialize workshop opens, in the status's place, filled the same way;
 * Confirm writes the manifest, after which the pane reads the project
 * again and the group shows its fields. Cancel goes back to the status.
 */
export function NoManifest() {
  const { selected } = useWorkshop();
  const [open, setOpen] = useState(false);
  const name = folderName(selected);
  if (open) {
    return <SetUpShop root={selected} name={name} onCancel={() => setOpen(false)} />;
  }

  return (
    <div role="status" className={cn('workshop-no-manifest', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
      <p className={cn('workshop-no-manifest-what', 'font-semibold')}>{`${name} has no manifest yet.`}</p>
      <p className={cn('workshop-no-manifest-why', 'text-(--ui-text-secondary)')}>{WHY}</p>
      <Button size="xs" className={cn('workshop-create-manifest-button', 'self-start')} onClick={() => setOpen(true)}>Create manifest</Button>
    </div>
  );
}
