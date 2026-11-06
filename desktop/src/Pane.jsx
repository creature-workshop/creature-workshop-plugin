/**
 * @file The pane: the project's name and root, three tabs, and the refresh
 * that keeps the toolchain current. `cwd` is the session's directory, `rest`
 * the backend call, `every` schedules the refresh and returns a disposer, and
 * `whenSettingsChange` subscribes to a save of the plugin's settings and
 * returns a disposer; all four come from the SDK in PaneWithSession.jsx and
 * from the harness in the tests.
 */
import { useEffect, useState } from 'react';
import { Declaration } from './Declaration.jsx';
import { Empty } from './Empty.jsx';
import { Release } from './Release.jsx';
import { Toolchain } from './Toolchain.jsx';
import { load, refreshMs } from './project.js';
import { useProject } from './store.js';

/** The tabs, in order; the first is the one the pane opens on. */
export const TABS = ['Toolchain', 'Declaration', 'Release'];

/**
 * The pane.
 * @param props The component's props.
 * @param props.store The store the pane and the chip share.
 * @param props.cwd The session's directory.
 * @param props.rest The backend call, taking a path under the plugin's API.
 * @param props.every Schedules a function on an interval in milliseconds and returns a disposer.
 * @param props.whenSettingsChange Subscribes to a save of the plugin's settings and returns a disposer.
 */
export function Pane({ store, cwd, rest, every, whenSettingsChange }) {
  const project = useProject(store);
  const [tab, setTab] = useState(TABS[0]);
  const intervalMs = refreshMs(project);

  useEffect(() => {
    load(rest, store, cwd, true);
    return whenSettingsChange(() => load(rest, store, cwd, false));
  }, [cwd, store]);

  useEffect(() => every(() => load(rest, store, cwd, true), intervalMs), [cwd, store, intervalMs]);

  if (!project.found) {
    return <Empty project={project} cwd={cwd} />;
  }

  const body = tab === 'Toolchain'
    ? <Toolchain project={project} />
    : tab === 'Declaration'
      ? <Declaration project={project} />
      : <Release project={project} />;
  return (
    <div className="flex h-full flex-col gap-2 overflow-auto p-3 text-sm">
      <div className="font-medium">{project.name || 'Creature Workshop'}</div>
      <div className="text-[0.6875rem] text-(--ui-text-tertiary)">{project.root}</div>
      <div className="flex gap-1">
        {TABS.map((name) => (
          <button
            key={name}
            type="button"
            className="rounded px-2 py-0.5 text-xs"
            style={{ background: name === tab ? 'var(--ui-bg-tertiary, rgba(127,127,127,0.2))' : 'transparent' }}
            onClick={() => setTab(name)}
          >
            {name}
          </button>
        ))}
      </div>
      {body}
    </div>
  );
}
