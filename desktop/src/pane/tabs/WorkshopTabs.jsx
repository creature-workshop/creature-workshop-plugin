/**
 * @file The Workshop tabs under the header: Desktop's pill tabs, one for
 * each tab in tabs/index.js, with the open tab's panel below them. They show
 * only when the selected repository is the root of a shellops project,
 * because every tab reads that project. When reading the project failed,
 * they say so in their place, with Try again.
 */

import { cn, Tabs } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { TABS } from '../../tabs/index.js';
import { FailureNotice } from '../../failures/FailureNotice.jsx';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { TabPanel } from './TabPanel.jsx';
import { TabStrip } from './TabStrip.jsx';

/**
 * Shows the tab strip and the open tab's panel. The first tab is open at
 * first. Shows "I couldn't read the project in <repository>." with why, what to try and
 * Try again when GET /project failed, and nothing when the selected
 * repository is not the root of a shellops project.
 *
 * @param props The component's props.
 * @param {readonly import('../../tabs/index.js').Tab[]} [props.tabs] The tabs, in order; every Workshop tab by default.
 */
export function WorkshopTabs({ tabs = TABS }) {
  const { project, selected, retry } = useWorkshop();
  const [open, setOpen] = useState(tabs[0].id);
  if (selected && project.state === 'failure') {
    return (
      <div className={cn('workshop-project-failure', 'px-3', 'py-2')}>
        <FailureNotice what={`I couldn't read the project in ${folderName(selected)}.`} error={project.error} onRetry={() => retry('project')} />
      </div>
    );
  }
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
 * @param project GET /project's answer for the selected repository, as remote data.
 * @param selected The selected repository's root, or an empty string.
 */
function adopted(project, selected) {
  return Boolean(selected && project.state === 'success' && project.data.found && project.data.root === selected);
}

/**
 * The last part of a path, the name a repository goes by.
 *
 * @param {string} path The repository's root.
 */
function folderName(path) {
  return path.split('/').filter(Boolean).pop() ?? path;
}
