/**
 * @file The Toolchain tab: the count of installed tools, one Row per
 * declared tool, and what install --check said on stderr when it said
 * anything.
 */
import { Row } from './Row.jsx';
import { toolchainSummary } from './project.js';

export function Toolchain({ project }) {
  const { rows, installed, total } = toolchainSummary(project);
  if (!project.toolchain) {
    return <div className="text-xs text-(--ui-text-tertiary)">checking the toolchain…</div>;
  }

  return (
    <div>
      <div className="mb-1 text-xs text-(--ui-text-tertiary)">{`${installed} of ${total} declared tools installed`}</div>
      {rows.map((row) => <Row key={`${row.channel}/${row.tool}`} {...row} />)}
      {project.toolchain.stderr
        ? <pre className="mt-2 whitespace-pre-wrap text-[0.6875rem] text-(--ui-text-tertiary)">{project.toolchain.stderr}</pre>
        : null}
    </div>
  );
}
