/**
 * @file The pane's body, between the header and the footer: what the
 * selected checkout is missing when it is not set up for shellops, else the
 * Workshop tabs.
 */

import { folderName } from '../../repos/folderName.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { WorkshopTabs } from '../tabs/WorkshopTabs.jsx';
import { SetupFailed } from './SetupFailed.jsx';
import { SetupNotice } from './SetupNotice.jsx';

/**
 * Shows "I couldn't tell whether <checkout> is set up." with why, what to
 * try and Try again when GET /project/setup failed; what the checkout is
 * missing when it is not ready; and otherwise the tabs, which show only
 * for a shellops project.
 */
export function WorkshopBody() {
  const { selected, setup, retry } = useWorkshop();
  if (selected && setup.state === 'failure') {
    return <SetupFailed name={folderName(selected)} error={setup.error} onRetry={() => retry('setup')} />;
  }
  if (selected && setup.state === 'success' && setup.data.state !== 'ready') {
    return <SetupNotice state={setup.data.state} name={folderName(selected)} />;
  }

  return <WorkshopTabs />;
}
