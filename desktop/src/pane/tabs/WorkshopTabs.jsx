/**
 * @file The Workshop tabs under the header: Desktop's pill tabs, one for
 * each tab in tabs/index.js, with the open tab's panel below them. They show
 * only when the selected repository is the root of a shellops project,
 * because every tab reads that project.
 */

import { cn, Tabs } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { TABS } from '../../tabs/index.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { TabPanel } from './TabPanel.jsx';
import { TabStrip } from './TabStrip.jsx';

/**
 * Shows the tab strip and the open tab's panel. The first tab is open at
 * first. Shows nothing when the selected repository is not the root of a
 * shellops project.
 *
 * @param props The component's props.
 * @param {readonly import('../../tabs/index.js').Tab[]} [props.tabs] The tabs, in order; every Workshop tab by default.
 */
export function WorkshopTabs({ tabs = TABS }) {
  const { project, selected } = useWorkshop();
  const [open, setOpen] = useState(tabs[0].id);
  if (!adopted(project, selected)) {
    return null;
  }
  const tab = tabs.find((each) => each.id === open) ?? tabs[0];

  return (
    <Tabs
      value={tab.id}
      onValueChange={setOpen}
      className={cn(
        'workshop-tabs',
        'flex',
        'min-h-0',
        'flex-1',
        'flex-col',
        'gap-2',
        'px-3',
        'py-2',
      )}
    >
      <TabStrip tabs={tabs} />
      <TabPanel tab={tab} />
    </Tabs>
  );
}

/**
 * Returns whether the selected repository is the root of its shellops project.
 *
 * @param project The answer to GET /project for the selected repository, or null.
 * @param selected The selected repository's root, or an empty string.
 */
function adopted(project, selected) {
  return Boolean(selected && project?.found && project.root === selected);
}
