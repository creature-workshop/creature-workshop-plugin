/**
 * @file The pane: the ProjectHeader, the Tabs, the open tab's body, and the
 * refresh that keeps the toolchain current. `cwd` is the session's directory, `rest`
 * the backend call, `every` schedules the refresh and returns a disposer, and
 * `whenSettingsChange` subscribes to a save of the plugin's settings and
 * returns a disposer; all four come from the SDK in SessionPane.jsx and
 * from the harness in the tests.
 */
import { useEffect, useState } from 'react';
import { NoProject } from './NoProject.jsx';
import { ProjectHeader } from './ProjectHeader.jsx';
import { Tabs } from './Tabs.jsx';
import { DeclarationTab } from './tabs/DeclarationTab.jsx';
import { ReleaseTab } from './tabs/ReleaseTab.jsx';
import { ToolchainTab } from './tabs/ToolchainTab.jsx';
import { load } from '../project/load.js';
import { refreshMs } from '../project/refresh.js';
import { useProject } from '../project/store.js';

/** The component of each tab, by the tab's name; the first is the one the pane opens on. */
const BODIES = { Toolchain: ToolchainTab, Declaration: DeclarationTab, Release: ReleaseTab };

/** The tabs, in order. */
export const TABS = Object.keys(BODIES);

/**
 * The pane.
 * @param props The component's props.
 * @param props.store The store the pane and the chip share.
 * @param props.cwd The session's directory.
 * @param props.rest The backend call, taking a path under the plugin's API.
 * @param props.every Schedules a function on an interval in milliseconds and returns a disposer.
 * @param props.whenSettingsChange Subscribes to a save of the plugin's settings and returns a disposer.
 */
export function WorkshopPane({ store, cwd, rest, every, whenSettingsChange }) {
  const project = useProject(store);
  const [tab, setTab] = useState(TABS[0]);
  const intervalMs = refreshMs(project);

  /** Loads the project when the directory changes, and again, without the check, on each save of the settings. */
  useEffect(() => {
    load(rest, store, cwd, true);
    return whenSettingsChange(() => load(rest, store, cwd, false));
  }, [cwd, store]);

  /** Re-runs the check on the interval, and reschedules when the interval setting changes. */
  useEffect(() => {
    const stop = every(() => load(rest, store, cwd, true), intervalMs);
    return stop;
  }, [cwd, store, intervalMs]);

  if (!project.found) {
    return <NoProject project={project} cwd={cwd} />;
  }

  const Body = BODIES[tab];
  return (
    <section className="workshop-pane flex h-full flex-col gap-2 overflow-auto p-3 text-sm">
      <ProjectHeader project={project} />
      <Tabs names={TABS} open={tab} onOpen={setTab} />
      <Body project={project} />
    </section>
  );
}
