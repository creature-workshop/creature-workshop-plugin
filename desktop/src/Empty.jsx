/**
 * @file What the pane shows outside a project: the backend's error when
 * there is one, else that the directory has no shellops project and how a
 * project gets one.
 */

export function Empty({ project, cwd }) {
  return (
    <div className="flex h-full flex-col gap-2 p-3 text-sm">
      <div className="font-medium">Creature Workshop</div>
      <div className="text-xs text-(--ui-text-tertiary)">
        {project.error ? `backend: ${project.error}` : `No shellops project at ${cwd || 'the session directory'}.`}
      </div>
      <div className="text-xs text-(--ui-text-tertiary)">
        A project gets one with: git submodule add &lt;shellops&gt; shell/.ops &amp;&amp; shell/.ops/init
      </div>
    </div>
  );
}
