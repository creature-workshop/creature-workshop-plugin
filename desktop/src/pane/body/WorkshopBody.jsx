/**
 * @file The pane's body, between the header and the footer: Set up shop
 * when the selected checkout's branch has no workshop, else the Workshop
 * tabs.
 */

import { folderName } from '../../repos/folderName.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { WorkshopTabs } from '../tabs/WorkshopTabs.jsx';
import { SetupFailed } from './SetupFailed.jsx';
import { NoWorkshop } from './adoption/NoWorkshop.jsx';

/**
 * Shows "I couldn't tell whether <checkout> is set up." with why, what to
 * try and Try again when GET /project/setup failed; the notice with Set up
 * shop when its branch has no workshop; and otherwise the tabs, which show
 * only for a shellops project.
 */
export function WorkshopBody() {
  const { selected, setup, retry } = useWorkshop();
  if (selected && setup.state === 'failure') {
    return <SetupFailed name={folderName(selected)} error={setup.error} onRetry={() => retry('setup')} />;
  }
  if (selected && setup.state === 'success' && setup.data.state === 'no-workshop') {
    return <NoWorkshop root={selected} name={folderName(selected)} />;
  }

  return <WorkshopTabs />;
}
