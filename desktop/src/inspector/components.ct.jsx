/**
 * @file The shared component suite: every built-in field component passes
 * the same cases, mounted through the Harness story. It shows its value,
 * a save commits a set of the trimmed text, a read-only field has no
 * pencil, and a refused commit keeps the editor open with the message.
 * After them, the cases every field shows the same way whatever its
 * component: the three states, Remove, a key the schema does not describe,
 * and a component that does not fit.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Harness } from './components.story.jsx';

/** The id of every built-in, each run through the suite. */
const BUILT_INS = ['text', 'multiline'];

/**
 * The value shown under the field's name.
 *
 * @param component The mounted harness.
 */
function valueOf(component) {
  return component.getByRole('group', { name: 'Field' }).getByRole('definition');
}

for (const id of BUILT_INS) {
  test.describe(`the ${id} component`, () => {
    test('shows its value', async ({ mount }) => {
      const component = await mount(<Harness component={id} />);

      await expect(valueOf(component)).toHaveText('Notes');
    });

    test('commits a set of the trimmed text', async ({ mount }) => {
      const component = await mount(<Harness component={id} />);

      await component.getByRole('button', { name: 'Edit Field' }).click();
      await component.getByRole('textbox', { name: 'Field' }).fill('  Field notes  ');
      await component.getByRole('button', { name: 'Save' }).click();

      await expect(component.getByRole('status', { name: 'Last commit' })).toHaveText('{"op":"set","value":"Field notes"}');
      await expect(valueOf(component)).toHaveText('Field notes');
    });

    test('has no pencil when read-only', async ({ mount }) => {
      const component = await mount(<Harness component={id} readOnly />);

      await expect(valueOf(component)).toHaveText('Notes');
      await expect(component.getByRole('button', { name: 'Edit Field' })).toHaveCount(0);
    });

    test('keeps the editor open with the message when a commit is refused', async ({ mount }) => {
      const component = await mount(<Harness component={id} refusing />);

      await component.getByRole('button', { name: 'Edit Field' }).click();
      await component.getByRole('textbox', { name: 'Field' }).fill('Field notes');
      await component.getByRole('button', { name: 'Save' }).click();

      await expect(component.getByRole('alert')).toHaveText('Refused for a reason.');
      await expect(component.getByRole('textbox', { name: 'Field' })).toHaveValue('Field notes');
    });
  });
}

test('an untouched key reads Not set with the default, a cleared one Cleared, and an empty string Empty', async ({ mount }) => {
  const untouched = await mount(<Harness component="text" fieldKey="note" />);
  await expect(valueOf(untouched)).toHaveText('Not set (default: none)');
  await untouched.unmount();

  const cleared = await mount(
    <Harness component="text" fieldKey="note" values={{ title: 'Notes', note: null }} />,
  );
  await expect(valueOf(cleared)).toHaveText('Cleared');
  await cleared.unmount();

  const empty = await mount(<Harness component="text" fieldKey="note" values={{ title: 'Notes', note: '' }} />);
  await expect(valueOf(empty)).toHaveText('Empty');
});

test('Remove clears a key that may be cleared', async ({ mount }) => {
  const component = await mount(
    <Harness component="text" fieldKey="note" values={{ title: 'Notes', note: 'draft' }} />,
  );

  await component.getByRole('button', { name: 'Edit Field' }).click();
  await component.getByRole('button', { name: 'Remove' }).click();

  await expect(component.getByRole('status', { name: 'Last commit' })).toHaveText('{"op":"clear"}');
  await expect(valueOf(component)).toHaveText('Cleared');
});

test('a required key has no Remove, and cannot be saved empty', async ({ mount }) => {
  const component = await mount(<Harness component="text" />);

  await component.getByRole('button', { name: 'Edit Field' }).click();
  await expect(component.getByRole('button', { name: 'Remove' })).toHaveCount(0);
  await component.getByRole('textbox', { name: 'Field' }).fill('  ');
  await component.getByRole('button', { name: 'Save' }).click();

  await expect(component.getByRole('alert')).toHaveText('Field cannot be empty.');
  await expect(component.getByRole('status', { name: 'Last commit' })).toHaveText('');
});

test('a component that does not fit the key says why, with no editor', async ({ mount }) => {
  const component = await mount(<Harness component="text" fieldKey="count" />);

  await expect(component.getByRole('alert')).toHaveText('text stores a string, but count is an integer.');
  await expect(component.getByRole('button', { name: 'Edit Field' })).toHaveCount(0);
});

test('a key the schema does not describe is not shown', async ({ mount }) => {
  const component = await mount(<Harness component="text" fieldKey="gone" />);

  await expect(component.getByRole('status', { name: 'Last commit' })).toBeAttached();
  await expect(component.getByRole('group', { name: 'Field' })).toHaveCount(0);
});

test('a component nobody registered says so', async ({ mount }) => {
  const component = await mount(<Harness component="slider" />);

  await expect(component.getByRole('alert')).toHaveText('There is no component named slider.');
});
