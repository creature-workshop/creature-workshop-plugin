/**
 * @file The Dependencies tab's panel: the tools the selected project
 * declares in .ops/config/tools.yaml, grouped by the channel that installs
 * each, with its declared version and whether it is installed right now.
 */

import { cn } from '@hermes/plugin-sdk';
import { FailureNotice } from '../../failures/FailureNotice.jsx';
import { FieldGroup } from '../../inspector/FieldGroup.jsx';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { channelsOf, summaryOf, uncheckable } from './dependencies.js';
import { DependencyRow } from './DependencyRow.jsx';
import { useToolchain } from './useToolchain.js';

/** What the panel says for a project that declares no tools. */
const NONE = 'This project declares no dependencies yet. They go in .ops/config/tools.yaml.';

/** What the panel says when the check finished and told nothing about any tool. */
const UNCHECKED = "I couldn't tell which of these are installed: the check said nothing about them.";

/**
 * Shows how many dependencies the project declares and how many are
 * missing, then one group for each channel, named after it, with a row for
 * each tool, which has an Explain button that asks the model why the
 * project has it. The list shows at once, from the declaration; each row says
 * Checking until `ops install --check` has answered, then Installed or
 * Missing. The list follows the declaration: a tool added to tools.yaml
 * outside the pane shows within 5 seconds, and the check runs again. When
 * the check could not be asked for, the panel says why above
 * the list, with Try again; when it answered nothing about the tools, it
 * says so. A project that declares no tools gets one line saying where
 * they go.
 */
export function DependenciesPanel() {
  const { project, selected } = useWorkshop();
  const { check, recheck } = useToolchain(selected, project.data.declared);
  const groups = channelsOf(project.data.declared, check);
  if (groups.length === 0) {
    return <p className={cn('workshop-dependencies-none', 'text-(--ui-text-secondary)')}>{NONE}</p>;
  }

  return (
    <div className={cn('workshop-dependencies', 'flex', 'flex-col', 'gap-5')}>
      <p role="status" className={cn('workshop-dependencies-summary', 'text-(--ui-text-secondary)')}>{summaryOf(groups)}</p>
      {check.state === 'failure' && <FailureNotice what="I couldn't check which of these are installed." error={check.error} onRetry={recheck} />}
      {uncheckable(check, groups) && <p className={cn('workshop-dependencies-unchecked', 'text-(--ui-text-tertiary)')}>{UNCHECKED}</p>}
      {groups.map((group) => (
        <FieldGroup key={group.channel} title={group.channel}>
          {group.tools.map((each) => <DependencyRow key={each.tool} tool={each.tool} version={each.version} status={each.status} />)}
        </FieldGroup>
      ))}
    </div>
  );
}
