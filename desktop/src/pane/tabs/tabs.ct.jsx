/**
 * @file Moving between the Workshop tabs: clicking a tab selects it and
 * shows its panel in place of the one before, and the first tab is open at
 * first. The tests mount the stories in WorkshopTabs.story.jsx.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { TwoTabs } from './WorkshopTabs.story.jsx';

test('the first tab is open at first', async ({ mount }) => {
  const component = await mount(<TwoTabs />);

  await expect(component.getByRole('tab', { name: 'Project Info', selected: true })).toBeVisible();
  await expect(component.getByRole('tab', { name: 'Second', selected: false })).toBeVisible();
  await expect(component.getByRole('tabpanel', { name: 'Project Info' })).toBeVisible();
});

test('clicking a tab selects it and shows its panel', async ({ mount }) => {
  const component = await mount(<TwoTabs />);

  await component.getByRole('tab', { name: 'Second' }).click();
  await expect(component.getByRole('tab', { name: 'Second', selected: true })).toBeVisible();
  await expect(component.getByRole('tabpanel', { name: 'Second' })).toHaveText('The second panel');
  await expect(component.getByRole('tabpanel', { name: 'Project Info' })).toHaveCount(0);

  await component.getByRole('tab', { name: 'Project Info' }).click();
  await expect(component.getByRole('tabpanel', { name: 'Project Info' })).toBeVisible();
});
