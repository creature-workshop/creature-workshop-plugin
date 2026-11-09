/**
 * @file What a user sees in the pane: a region named Workshop, and nothing
 * in it. The test mounts the pane and reads it by role, never by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { WorkshopPane } from './WorkshopPane.jsx';

test('the pane is a region named Workshop with nothing in it', async ({ mount }) => {
  const component = await mount(<WorkshopPane />);

  const pane = component.getByRole('region', { name: 'Workshop' });
  await expect(pane).toBeVisible();
  await expect(pane).toBeEmpty();
});
