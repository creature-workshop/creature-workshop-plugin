/**
 * @file The Release tab: the latest and stable versions from the lock, and
 * how many tools the project declares.
 */

/**
 * The Release tab.
 * @param props The component's props.
 * @param props.project The loaded project.
 */
export function Release({ project }) {
  const record = project.release || {};
  const declared = project.declared || [];
  return (
    <div className="text-xs">
      <div>{`latest: ${record.latest || 'none yet'}`}</div>
      <div>{`stable: ${record.stable || 'none yet'}`}</div>
      <div className="mt-2 text-(--ui-text-tertiary)">{`${declared.length} tools declared by this project`}</div>
    </div>
  );
}
