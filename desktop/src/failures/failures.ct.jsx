/**
 * @file The error boundary: a part that crashes says it stopped and that
 * the rest of the pane still works, the parts beside it keep drawing, the
 * details hold the error once, and Try again draws the part again. A
 * crashed footer says only that the plugin's version is unavailable.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { CrashingOnce, FooterCrashing } from './failures.story.jsx';

test('a crashed part says it stopped, leaves the rest drawn, and comes back on Try again', async ({ mount }) => {
  const component = await mount(<CrashingOnce />);
  const alert = component.getByRole('alert');

  await expect(alert).toContainText('The tabs stopped working.');
  await expect(alert).toContainText('the rest of the pane still works.');
  await expect(component.getByText('Still here')).toBeVisible();
  await alert.getByRole('button', { name: 'Show details' }).click();
  await expect(alert.getByText(/Error: Boom/)).toHaveCount(1);
  await alert.getByRole('button', { name: 'Try again' }).click();

  await expect(component.getByText('Back again')).toBeVisible();
  await expect(component.getByRole('alert')).toHaveCount(0);
});

test('a crashed footer says only that the Workshop plugin version is unavailable, with the reason in its (i)', async ({ mount, page }) => {
  const component = await mount(<FooterCrashing />);
  const footer = component.getByRole('contentinfo');

  await expect(footer).toHaveText('Workshop plugin version unavailable');
  await expect(component.getByRole('alert')).toHaveCount(0);
  await footer.getByRole('button', { name: 'About Version' }).hover();

  await expect(page.getByRole('tooltip')).toContainText("Something in the footer's code went wrong: Boom");
});
