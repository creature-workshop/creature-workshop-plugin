/**
 * @file The row of tab buttons at the top of the Workshop tabs.
 */

import { cn, TabsList, TabsTrigger } from '@hermes/plugin-sdk';

/**
 * The corner radius of each tab: the strip's radius minus the 4px padding
 * inside the strip, so the tab's corners follow the strip's. Desktop's own
 * tab is rounder than its strip. This is an inline style because Desktop's
 * stylesheet only has the classes Desktop itself uses.
 */
const TRIGGER_STYLE = { borderRadius: 'max(0px, calc(var(--radius-scalar) * 0.75rem - 0.25rem))' };

/**
 * Shows one pill button for each tab, in Desktop's tab strip. Must sit
 * inside the SDK's Tabs, which tracks the open tab.
 *
 * @param props The component's props.
 * @param {readonly import('../../tabs/index.js').Tab[]} props.tabs The tabs, in order.
 */
export function TabStrip({ tabs }) {
  return (
    <TabsList aria-label="Workshop tabs" className={cn('self-start')}>
      {tabs.map((each) => <TabsTrigger key={each.id} value={each.id} style={TRIGGER_STYLE}>{each.label}</TabsTrigger>)}
    </TabsList>
  );
}
