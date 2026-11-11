/**
 * @file The pane's body, between the header and the footer: Set up shop
 * when the selected checkout's branch has no workshop, else the Workshop
 * tabs; and in their place, while the project is not approved, a notice
 * with Approve project.
 */

import { folderName } from '../../repos/folderName.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { WorkshopTabs } from '../tabs/WorkshopTabs.jsx';
import { SetupFailed } from './SetupFailed.jsx';
import { NoWorkshop } from './adoption/NoWorkshop.jsx';
import { NotApproved } from './approval/NotApproved.jsx';
import { unapproved } from './approval/unapproved.js';

/**
 * Shows "I couldn't tell whether <checkout> is set up." with why, what to
 * try and Try again when GET /project/setup failed; the notice with
 * Initialize workshop when its branch has no workshop; and otherwise the tabs, which show
 * only for a shellops project. A project the user has not approved shows
 * the approval notice alone, in the middle of the body, and no tabs.
 */
export function WorkshopBody() {
  const { selected, setup, project, retry } = useWorkshop();
  if (selected && setup.state === 'failure') {
    return <SetupFailed name={folderName(selected)} error={setup.error} onRetry={() => retry('setup')} />;
  }
  if (selected && setup.state === 'success' && setup.data.state === 'no-workshop') {
    return <NoWorkshop root={selected} name={folderName(selected)} />;
  }

  if (unapproved(project, selected)) {
    return <NotApproved root={selected} name={folderName(selected)} />;
  }

  return <WorkshopTabs />;
}
