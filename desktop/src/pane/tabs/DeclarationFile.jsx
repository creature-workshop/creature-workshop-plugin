/**
 * @file One file of the declaration, as the Declaration tab shows it: its
 * path under .ops/config, and its text as it is.
 */

/**
 * One declaration file.
 * @param props The component's props.
 * @param props.name The file's name under .ops/config.
 * @param props.text The file's text.
 */
export function DeclarationFile({ name, text }) {
  return (
    <div className="workshop-declaration-file mb-3">
      <div className="text-xs font-medium">{`.ops/config/${name}`}</div>
      <pre className="whitespace-pre-wrap text-[0.6875rem] text-(--ui-text-secondary)">{text}</pre>
    </div>
  );
}
