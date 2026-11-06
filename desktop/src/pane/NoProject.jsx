/**
 * @file What the pane shows outside a project: the backend's error when
 * there is one, else that the directory has no shellops project and how a
 * project gets one.
 */

/**
 * The pane's body outside a project.
 * @param props The component's props.
 * @param props.project The project as loaded, which was not found.
 * @param props.cwd The session's directory.
 */
export function NoProject({ project, cwd }) {
  return (
    <div className="workshop-no-project flex h-full flex-col gap-2 p-3 text-sm">
      <div className="workshop-no-project-title font-medium">Creature Workshop</div>
      <div className="workshop-no-project-reason text-xs text-(--ui-text-tertiary)">
        {project.error ? `backend: ${project.error}` : `No shellops project at ${cwd || 'the session directory'}.`}
      </div>
      <div className="workshop-no-project-hint text-xs text-(--ui-text-tertiary)">
        A project gets one with: git submodule add &lt;shellops&gt; shell/.ops &amp;&amp; shell/.ops/init
      </div>
    </div>
  );
}
