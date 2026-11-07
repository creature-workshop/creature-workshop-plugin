/**
 * @file The Toolchain tab: the count of installed tools, one ToolchainRow per
 * declared tool, and what install --check said on stderr when it said
 * anything.
 */

import { toolchainSummary } from '../../project/toolchain.js';
import { ToolchainRow } from './ToolchainRow.jsx';

/**
 * The Toolchain tab.
 * @param props The component's props.
 * @param props.project The loaded project.
 */
export function ToolchainTab({ project }) {
  const { rows, installed, total } = toolchainSummary(project);
  if (!project.toolchain) {
    return <div className="workshop-toolchain-pending text-xs text-(--ui-text-tertiary)">checking the toolchain…</div>;
  }

  return (
    <div className="workshop-toolchain">
      <div className="workshop-toolchain-count mb-1 text-xs text-(--ui-text-tertiary)">{`${installed} of ${total} declared tools installed`}</div>
      {rows.map((row) => <ToolchainRow key={`${row.channel}/${row.tool}`} {...row} />)}
      {project.toolchain.stderr
        ? <pre className="mt-2 whitespace-pre-wrap text-[0.6875rem] text-(--ui-text-tertiary)">{project.toolchain.stderr}</pre>
        : null}
    </div>
  );
}
