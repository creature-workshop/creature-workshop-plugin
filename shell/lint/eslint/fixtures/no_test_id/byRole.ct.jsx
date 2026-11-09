/** @file A test that finds the page by role and by text. */
import { expect, test } from '@playwright/experimental-ct-react';

test('reads the status', async ({ mount }) => {
  const component = await mount(<span role="status">ready</span>);
  await expect(component.getByRole('status')).toHaveText('ready');
});
