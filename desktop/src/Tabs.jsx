/**
 * @file The pane's tab bar: one button per tab, the open one shaded.
 */

/**
 * The tab bar.
 * @param props The component's props.
 * @param props.names The tabs, in order.
 * @param props.open The name of the open tab.
 * @param props.onOpen Called with a tab's name when its button is clicked.
 */
export function Tabs({ names, open, onOpen }) {
  return (
    <nav className="workshop-tabs flex gap-1" aria-label="Pane tabs">
      {names.map((name) => (
        <button
          key={name}
          type="button"
          className="rounded px-2 py-0.5 text-xs"
          style={{ background: name === open ? 'var(--ui-bg-tertiary, rgba(127,127,127,0.2))' : 'transparent' }}
          onClick={() => onOpen(name)}
        >
          {name}
        </button>
      ))}
    </nav>
  );
}
