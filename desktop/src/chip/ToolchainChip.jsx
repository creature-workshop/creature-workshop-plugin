/**
 * @file The status-bar chip: how many declared tools are installed, green
 * when all of them are, red when one is missing, and a note when the
 * session is not in a project. It is a status role, which is what it is in
 * Desktop's bar and how the tests find it.
 */
import { useProject } from '../project/store.js';
import { toolchainSummary } from '../project/toolchain.js';

/**
 * The chip's colour: muted with nothing declared, green with everything installed, red otherwise.
 * @param installed How many declared tools are installed.
 * @param total How many tools are declared.
 */
function chipColor(installed, total) {
  if (total === 0) {
    return 'var(--ui-text-tertiary)';
  }

  return installed === total ? '#3fb950' : '#f85149';
}

/**
 * The chip: `toolchain <installed>/<declared>`, or a note outside a project.
 * @param props The component's props.
 * @param props.store The store the pane and the chip share.
 */
export function ToolchainChip({ store }) {
  const project = useProject(store);
  if (!project.found) {
    return <span role="status" className="px-1.5 text-[0.6875rem] text-(--ui-text-tertiary)">no .ops here</span>;
  }

  const { installed, total } = toolchainSummary(project);
  return (
    <span role="status" className="px-1.5 text-[0.6875rem]" style={{ color: chipColor(installed, total) }} title={project.summary || ''}>
      toolchain {`${installed}/${total}`}
    </span>
  );
}
