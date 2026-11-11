/**
 * @file One dependency in the Dependencies tab: its name, the version the
 * project declares, whether it is installed, and an Explain button that
 * asks the model why the project has it.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { DependencyStatus } from './DependencyStatus.jsx';
import { Explanation } from './Explanation.jsx';
import { useExplanation } from './useExplanation.js';

/** The row's first line is at least 24px tall, as a field's name row is; what follows wraps under it. */
const ROW_STYLE = Object.freeze({ display: 'flex', flexWrap: 'wrap', alignItems: 'center', columnGap: '0.5rem', minHeight: '1.5rem' });

/** The name gives way first when the row is too narrow, ending in an ellipsis. */
const NAME_STYLE = Object.freeze({ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' });

/** The version, the status and Explain share the rest of the first line and never wrap. */
const DETAILS_STYLE = Object.freeze({ flex: '1 1 0%', whiteSpace: 'nowrap' });

/** The explanation takes a line of its own under the first, with 4px above and 8px below. */
const EXPLANATION_STYLE = Object.freeze({ flex: '0 0 100%', margin: '0.25rem 0 0.5rem' });

/**
 * A group named after the tool, with a thin line under it. Its first line
 * holds the tool's name in semibold, its declared version, its status and
 * an Explain button at the far right. Explain asks the model why the
 * project has the tool and gives way to the answer, which shows under the
 * first line. Must sit inside a `<dl>`.
 *
 * @param props The component's props.
 * @param {string} props.tool The tool's name.
 * @param {string} props.version The version the project declares, or empty.
 * @param {string} props.status One of STATUS in dependencies.js.
 */
export function DependencyRow({ tool, version, status }) {
  const { selected } = useWorkshop();
  const { explanation, ask } = useExplanation(selected, tool);
  const asked = explanation.phase !== 'idle';

  return (
    <div role="group" aria-label={tool} className={cn('workshop-dependency', 'min-w-0', 'border-b', 'border-(--ui-stroke-tertiary)')} style={ROW_STYLE}>
      <dt className={cn('workshop-dependency-name', 'min-w-0', 'font-semibold')} style={NAME_STYLE}>{tool}</dt>
      <dd className={cn('workshop-dependency-details', 'flex', 'min-w-0', 'items-center', 'justify-between', 'gap-2')} style={DETAILS_STYLE}>
        <span className={cn('workshop-dependency-version', 'text-(--ui-text-tertiary)')}>{version}</span>
        <span className={cn('workshop-dependency-end', 'flex', 'items-center', 'gap-2')}>
          <DependencyStatus status={status} />
          {!asked && <Button size="xs" variant="ghost" aria-label={`Explain ${tool}`} onClick={ask}>Explain</Button>}
        </span>
      </dd>
      {asked && (
        <dd className={cn('workshop-dependency-explanation', 'min-w-0')} style={EXPLANATION_STYLE}>
          <Explanation tool={tool} explanation={explanation} onRetry={ask} />
        </dd>
      )}
    </div>
  );
}
