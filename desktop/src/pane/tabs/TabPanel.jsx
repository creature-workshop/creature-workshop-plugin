/**
 * @file The area under the tab strip that shows the open tab's content.
 */

import { cn } from '@hermes/plugin-sdk';
import { PartBoundary } from '../../failures/PartBoundary.jsx';

/**
 * Room around the content for what reaches past it, given as margin and
 * taken back as padding. Inline, because Desktop's stylesheet has no class
 * for a negative 8px margin.
 */
const ROOM = { margin: '-0.5rem', padding: '0.5rem' };

/**
 * Shows the open tab's Panel in a scrolling area labelled with the tab's
 * name, inside an error boundary, so a crash in the tab shows why in its
 * place and leaves the rest of the pane drawn. The SDK does not export a tab panel, so this one sets the tabpanel
 * role itself. The area reaches 8px past the content on every side, with
 * the same padding inside, because a scrolling area clips what it holds at
 * its edge: a control may reach 4px past the content (as a group heading
 * does) and Desktop draws a 3px focus ring outside it.
 *
 * @param props The component's props.
 * @param {import('../../tabs/index.js').Tab} props.tab The open tab.
 */
export function TabPanel({ tab }) {
  return (
    <section
      role="tabpanel"
      aria-label={tab.label}
      style={ROOM}
      className={cn(
        'workshop-tab-panel',
        'min-h-0',
        'flex-1',
        'overflow-auto',
        'text-[0.6875rem]',
      )}
    >
      <PartBoundary key={tab.id} part={`The ${tab.label} tab`}>
        <tab.Panel />
      </PartBoundary>
    </section>
  );
}
