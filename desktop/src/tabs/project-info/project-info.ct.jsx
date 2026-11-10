/**
 * @file Editing the Project Info fields: the pencil opens a field with its
 * value, Enter or Save keeps the change, Escape or Cancel drops it, a
 * required field cannot be emptied, an unset field reads Not set and can be
 * filled in, a save the store refuses keeps the editor open with the store's
 * reason, and a save over a change made outside the pane says so and shows
 * the current value. The tests mount the stories in ProjectInfoPanel.story.jsx.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { ChangedOutside, Editable, Refusing } from './ProjectInfoPanel.story.jsx';

/**
 * The value shown under a field's name.
 *
 * @param component The mounted tabs.
 * @param term The field's label.
 */
function valueOf(component, term) {
  return component.getByRole('group', { name: term }).getByRole('definition');
}

test('the pencil opens the field with its value, and Enter saves the change', async ({ mount }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'Edit Description' }).click();
  const field = component.getByRole('textbox', { name: 'Description' });
  await expect(field).toHaveValue('Notes, kept in git.');
  await field.fill('Notes and drafts.');
  await field.press('Enter');

  await expect(valueOf(component, 'Description')).toHaveText('Notes and drafts.');
  await expect(component.getByRole('textbox')).toHaveCount(0);
});

test('Save keeps the change and Cancel drops it', async ({ mount }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'Edit Name' }).click();
  await component.getByRole('textbox', { name: 'Name' }).fill('Field notes');
  await component.getByRole('button', { name: 'Save' }).click();
  await expect(valueOf(component, 'Name')).toHaveText('Field notes');

  await component.getByRole('button', { name: 'Edit Name' }).click();
  await component.getByRole('textbox', { name: 'Name' }).fill('Something else');
  await component.getByRole('button', { name: 'Cancel' }).click();
  await expect(valueOf(component, 'Name')).toHaveText('Field notes');
});

test('Escape closes the field without saving', async ({ mount }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'Edit Organization' }).click();
  const field = component.getByRole('textbox', { name: 'Organization' });
  await field.fill('nobody');
  await field.press('Escape');

  await expect(valueOf(component, 'Organization')).toHaveText('someone');
});

test('a required field cannot be emptied', async ({ mount }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'Edit Repository' }).click();
  await component.getByRole('textbox', { name: 'Repository' }).fill('  ');
  await component.getByRole('button', { name: 'Save' }).click();

  await expect(component.getByRole('alert')).toHaveText('Repository cannot be empty.');
  await expect(component.getByRole('textbox', { name: 'Repository' })).toBeVisible();
});

test('an unset field reads Not set and can be filled in', async ({ mount }) => {
  const component = await mount(<Editable />);

  await expect(valueOf(component, 'Command')).toHaveText('Not set');
  await component.getByRole('button', { name: 'Edit Command' }).click();
  await component.getByRole('textbox', { name: 'Command' }).fill('notes');
  await component.getByRole('textbox', { name: 'Command' }).press('Enter');

  await expect(valueOf(component, 'Command')).toHaveText('notes');
});

test('the (i) after a field name shows its description', async ({ mount, page }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'About Name' }).hover();

  await expect(page.getByRole('tooltip')).toHaveText('Human-readable project name.');
  await expect(component.getByRole('button', { name: 'About Organization' })).toHaveCount(0);
});

test('the read-only releases have an (i) too', async ({ mount, page }) => {
  const component = await mount(<Editable />);

  await component.getByRole('button', { name: 'About Stable' }).hover();

  await expect(page.getByRole('tooltip')).toContainText('not a prerelease');
  await expect(component.getByRole('button', { name: 'About Latest' })).toBeVisible();
});

test('a save the store refuses keeps the editor open and says why', async ({ mount }) => {
  const component = await mount(<Refusing />);

  await component.getByRole('button', { name: 'Edit Name' }).click();
  await component.getByRole('textbox', { name: 'Name' }).fill('Field notes');
  await component.getByRole('button', { name: 'Save' }).click();

  await expect(component.getByRole('alert')).toHaveText('description cannot be cleared: its schema has no empty value for it.');
  await expect(component.getByRole('textbox', { name: 'Name' })).toHaveValue('Field notes');
});

test('each field shows its name above its value, with the pencil on the name row', async ({ mount }) => {
  const component = await mount(<Editable />);

  const name = component.getByRole('group', { name: 'Name' });
  await expect(name.getByRole('term')).toContainText('Name');
  await expect(name.getByRole('term').getByRole('button', { name: 'Edit Name' })).toBeVisible();
  const term = await name.getByRole('term').boundingBox();
  const value = await name.getByRole('definition').boundingBox();
  expect(term.y + term.height).toBeLessThanOrEqual(value.y);
});

test('the editable manifest fields sit under Manifest, and the read-only releases under Versions', async ({ mount }) => {
  const component = await mount(<Editable />);

  const manifest = component.getByRole('region', { name: 'Manifest' });
  await expect(manifest.getByRole('heading', { name: 'Manifest' })).toBeVisible();
  await expect(manifest.getByRole('term')).toHaveText([
    'Name',
    'Description',
    'Command',
    'Organization',
    'Repository',
  ]);
  const versions = component.getByRole('region', { name: 'Versions' });
  await expect(versions.getByRole('term')).toHaveText(['Latest', 'Stable']);
  await expect(versions.getByRole('button', { name: /^Edit/ })).toHaveCount(0);
});

test('a group heading folds its fields away and unfolds them again', async ({ mount }) => {
  const component = await mount(<Editable />);

  const manifest = component.getByRole('region', { name: 'Manifest' });
  const heading = manifest.getByRole('button', { name: 'Manifest' });
  await expect(heading).toHaveAttribute('aria-expanded', 'true');
  await heading.click();
  await expect(heading).toHaveAttribute('aria-expanded', 'false');
  await expect(manifest.getByRole('term')).toHaveCount(0);
  await expect(component.getByRole('region', { name: 'Versions' }).getByRole('term')).toHaveText(['Latest', 'Stable']);

  await heading.click();
  await expect(manifest.getByRole('term')).toHaveCount(5);
});

test('a save over a change made outside the pane says so, and saving again replaces it', async ({ mount }) => {
  const component = await mount(<ChangedOutside />);

  await component.getByRole('button', { name: 'Edit Description' }).click();
  await component.getByRole('textbox', { name: 'Description' }).fill('Mine.');
  await component.getByRole('button', { name: 'Save' }).click();
  await expect(component.getByRole('alert')).toHaveText('This changed outside the pane. Cancel to see the current value, or save again to replace it.');

  await component.getByRole('button', { name: 'Cancel' }).click();
  await expect(valueOf(component, 'Description')).toHaveText('Edited by an agent.');

  await component.getByRole('button', { name: 'Edit Description' }).click();
  await component.getByRole('textbox', { name: 'Description' }).fill('Mine.');
  await component.getByRole('button', { name: 'Save' }).click();
  await expect(valueOf(component, 'Description')).toHaveText('Mine.');
});

