/**
 * @file The area under the tab strip that shows the open tab's content.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * Shows the open tab's Panel in a scrolling area labelled with the tab's
 * name. The SDK does not export a tab panel, so this one sets the tabpanel
 * role itself.
 *
 * @param props The component's props.
 * @param {import('../../tabs/index.js').Tab} props.tab The open tab.
 */
export function TabPanel({ tab }) {
  return (
    <section
      role="tabpanel"
      aria-label={tab.label}
      className={cn(
        'workshop-tab-panel',
        'min-h-0',
        'flex-1',
        'overflow-auto',
        'text-[0.6875rem]',
      )}
    >
      <tab.Panel />
    </section>
  );
}
