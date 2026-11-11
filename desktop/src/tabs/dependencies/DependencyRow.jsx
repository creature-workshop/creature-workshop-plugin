/**
 * @file One dependency in the Dependencies tab: its name, the version the
 * project declares, and whether it is installed.
 */

import { cn } from '@hermes/plugin-sdk';
import { DependencyStatus } from './DependencyStatus.jsx';

/** A row is at least 24px tall, as a field's name row is, and its two ends never wrap. */
const ROW_STYLE = Object.freeze({ minHeight: '1.5rem', whiteSpace: 'nowrap' });

/** The name gives way first when the row is too narrow, ending in an ellipsis. */
const NAME_STYLE = Object.freeze({ overflow: 'hidden', textOverflow: 'ellipsis' });

/**
 * A group named after the tool, on one line with a thin line under it:
 * the tool's name in semibold, then its declared version, and its status
 * at the far right. Must sit inside a `<dl>`.
 *
 * @param props The component's props.
 * @param {string} props.tool The tool's name.
 * @param {string} props.version The version the project declares, or empty.
 * @param {string} props.status One of STATUS in dependencies.js.
 */
export function DependencyRow({ tool, version, status }) {
  return (
    <div
      role="group"
      aria-label={tool}
      className={cn('workshop-dependency', 'flex', 'min-w-0', 'items-center', 'gap-2', 'border-b', 'border-(--ui-stroke-tertiary)')}
      style={ROW_STYLE}
    >
      <dt className={cn('workshop-dependency-name', 'min-w-0', 'font-semibold')} style={NAME_STYLE}>{tool}</dt>
      <dd className={cn('workshop-dependency-details', 'flex', 'min-w-0', 'flex-1', 'items-center', 'justify-between', 'gap-2')}>
        <span className={cn('workshop-dependency-version', 'text-(--ui-text-tertiary)')}>{version}</span>
        <DependencyStatus status={status} />
      </dd>
    </div>
  );
}
