/**
 * @file The status-bar chip: how many declared tools are installed, green
 * when all of them are, red when one is missing, and a note when the
 * session is not in a project.
 */
import { useProject } from './store.js';
import { toolchainSummary } from './project.js';

export function Chip({ store }) {
  const project = useProject(store);
  if (!project.found) {
    return <span className="px-1.5 text-[0.6875rem] text-(--ui-text-tertiary)">no .ops here</span>;
  }

  const { installed, total } = toolchainSummary(project);
  const allThere = total > 0 && installed === total;
  const color = total === 0 ? 'var(--ui-text-tertiary)' : allThere ? '#3fb950' : '#f85149';
  return (
    <span className="px-1.5 text-[0.6875rem]" style={{ color }} title={project.summary || ''}>
      toolchain {`${installed}/${total}`}
    </span>
  );
}
