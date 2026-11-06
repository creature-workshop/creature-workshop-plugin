/**
 * @file The pane's header: the project's name, and its root under it.
 */

/**
 * The header.
 * @param props The component's props.
 * @param props.project The loaded project.
 */
export function ProjectHeader({ project }) {
  return (
    <header className="workshop-project">
      <h2 className="workshop-project-name text-sm font-medium">{project.name || 'Creature Workshop'}</h2>
      <p className="workshop-project-root text-[0.6875rem] text-(--ui-text-tertiary)">{project.root}</p>
    </header>
  );
}
