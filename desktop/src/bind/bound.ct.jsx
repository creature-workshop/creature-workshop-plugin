/**
 * @file A component bound with a `bind` prop: an ordinary controlled text
 * box shows the value its binding names, shows what is typed at once, and
 * each change is written to the store at the revision the one before it
 * answered; and a binding that cannot be read shows a notice that names
 * the file in the component's place. The tests mount the stories in
 * Bound.story.jsx.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { BoundToAKey, Unreadable } from './Bound.story.jsx';

test('a bound component shows the value its binding names', async ({ mount }) => {
  const component = await mount(<BoundToAKey />);

  await expect(component.getByRole('textbox', { name: 'Name' })).toHaveValue('Notes');
});

test('typing shows at once and writes each change at the revision the last one answered', async ({ mount }) => {
  const sent = [];
  const component = await mount(<BoundToAKey onWrite={(body) => sent.push(body)} />);
  const box = component.getByRole('textbox', { name: 'Name' });

  await expect(box).toHaveValue('Notes');
  await box.press('End');
  await box.pressSequentially('!?');

  await expect(box).toHaveValue('Notes!?');
  await expect.poll(() => sent.map(({ value, revision }) => [value, revision])).toEqual([['Notes!', 'r1'], ['Notes!?', 'r1+']]);
});

test('a binding that cannot be read shows a notice that names the file, with Try again', async ({ mount }) => {
  const component = await mount(<Unreadable />);

  await expect(component.getByRole('alert')).toContainText("I couldn't read config/manifest.yaml.");
  await expect(component.getByRole('button', { name: 'Try again' })).toBeVisible();
  await expect(component.getByRole('textbox')).toHaveCount(0);
});
