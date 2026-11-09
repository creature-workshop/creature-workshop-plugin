/**
 * @file What the rest of the plugin gets from Wizard: the registered
 * implementation, handed the tool and every step, whose answers come back
 * through onFinish; and nothing at all when no implementation is registered.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Registered, Unregistered } from './Wizard.story.jsx';

test('the registered implementation gets the tool and every step', async ({ mount }) => {
  const component = await mount(<Registered onFinish={() => {}} />);

  await expect(component).toHaveAccessibleName('Set up notes');
  await expect(component.getByRole('listitem')).toHaveText(['Let us set up shop.', 'What is the project called?', 'Adopt it now?']);
});

test('the answers the implementation finishes with reach onFinish', async ({ mount }) => {
  const finished = [];
  const component = await mount(<Registered onFinish={(answers) => finished.push(answers)} />);

  await component.getByRole('button', { name: 'Finish' }).click();
  await expect.poll(() => finished).toEqual([{ name: 'notes', adopt: 'yes' }]);
});

test('with no implementation registered, the wizard shows nothing', async ({ mount }) => {
  const component = await mount(<Unregistered />);

  await expect(component).toBeEmpty();
});
