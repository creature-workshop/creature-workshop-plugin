/**
 * @file The Declaration tab: every file under .ops/config, by name, with its
 * text.
 */

/**
 * The Declaration tab.
 * @param props The component's props.
 * @param props.project The loaded project.
 */
export function Declaration({ project }) {
  const files = project.declaration || {};
  const names = Object.keys(files);
  if (names.length === 0) {
    return <div className="text-xs text-(--ui-text-tertiary)">no declaration files under .ops/config</div>;
  }

  return (
    <div>
      {names.map((name) => (
        <div key={name} className="mb-3">
          <div className="text-xs font-medium">{`.ops/config/${name}`}</div>
          <pre className="whitespace-pre-wrap text-[0.6875rem] text-(--ui-text-secondary)">{files[name]}</pre>
        </div>
      ))}
    </div>
  );
}
