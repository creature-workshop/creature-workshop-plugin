/**
 * @file The Declaration tab: every file under .ops/config, each a
 * DeclarationFile, in name order.
 */

import { DeclarationFile } from './DeclarationFile.jsx';

/**
 * The Declaration tab.
 * @param props The component's props.
 * @param props.project The loaded project.
 */
export function DeclarationTab({ project }) {
  const files = project.declaration || {};
  const names = Object.keys(files);
  if (names.length === 0) {
    return <div className="workshop-declaration-empty text-xs text-(--ui-text-tertiary)">no declaration files under .ops/config</div>;
  }

  return (
    <div className="workshop-declaration">
      {names.map((name) => <DeclarationFile key={name} name={name} text={files[name]} />)}
    </div>
  );
}
