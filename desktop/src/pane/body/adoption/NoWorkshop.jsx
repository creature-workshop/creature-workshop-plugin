/**
 * @file The pane body for a checkout whose branch has no workshop: the
 * notice with Initialize workshop, and the adoption wizard once it is pressed.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { SetupNotice } from '../SetupNotice.jsx';
import { SetUpShop } from './SetUpShop.jsx';

/**
 * The no-workshop notice with an Initialize workshop button, which opens the
 * adoption wizard in its place; Cancel in the wizard goes back.
 *
 * @param props The component's props.
 * @param {string} props.root The checkout's root.
 * @param {string} props.name The checkout's folder name.
 */
export function NoWorkshop({ root, name }) {
  const [open, setOpen] = useState(false);
  if (open) {
    return (
      <div className={cn('workshop-set-up-shop', 'flex', 'min-w-0', 'flex-col', 'gap-2', 'px-2', 'py-2')}>
        <SetUpShop root={root} name={name} onCancel={() => setOpen(false)} />
      </div>
    );
  }

  return (
    <SetupNotice state="no-workshop" name={name}>
      <Button size="xs" className={cn('workshop-set-up-shop-button')} onClick={() => setOpen(true)}>Initialize workshop</Button>
    </SetupNotice>
  );
}
