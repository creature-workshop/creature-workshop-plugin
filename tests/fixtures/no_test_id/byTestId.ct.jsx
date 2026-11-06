/** @file A test that plants a test id and finds the page by it. */
import { expect, test } from '@playwright/experimental-ct-react';

test('reads the status', async ({ mount }) => {
  const component = await mount(<span data-testid="status">ready</span>);
  await expect(component.getByTestId('status')).toHaveText('ready');
});
