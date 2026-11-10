/**
 * @file The shared component suite: every built-in field component passes
 * the same cases, mounted through the Harness story. Each built-in has a
 * driver that says which key it shows, what it shows, and how to change
 * it. It shows its value, a change commits a set of the new value, a
 * read-only field cannot be changed, and a refused commit shows the
 * message. After them come the cases particular to one component, and the
 * cases every field shows the same way: the three states, Remove, where
 * the help text comes from, a key the schema does not describe, and a
 * component that does not fit.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Harness } from './components.story.jsx';

/** Each built-in, with the key it shows, what it shows, and how to change it. */
const DRIVERS = [
  {
    id: 'text', fieldKey: 'title', shown: 'Notes', sent: '{"op":"set","value":"Field notes"}',
    change: (component) => typeAndSave(component, '  Field notes  '),
    locked: (component) => expect(control(component, 'button', 'Edit Field')).toHaveCount(0),
  },
  {
    id: 'multiline', fieldKey: 'title', shown: 'Notes', sent: '{"op":"set","value":"Field notes"}',
    change: (component) => typeAndSave(component, '  Field notes  '),
    locked: (component) => expect(control(component, 'button', 'Edit Field')).toHaveCount(0),
  },
  {
    id: 'number', fieldKey: 'count', shown: '3', sent: '{"op":"set","value":7}',
    change: (component) => typeAndSave(component, ' 7 '),
    locked: (component) => expect(control(component, 'button', 'Edit Field')).toHaveCount(0),
  },
  {
    id: 'select', fieldKey: 'channel', shown: 'dev', sent: '{"op":"set","value":"stable"}',
    change: (component, page) => pick(component, page, 'stable'),
    locked: (component) => expect(control(component, 'combobox', 'Field')).toBeDisabled(),
  },
  {
    id: 'switch', fieldKey: 'enabled', shown: 'On', sent: '{"op":"set","value":false}',
    change: (component) => control(component, 'switch', 'Field').click(),
    locked: (component) => expect(control(component, 'switch', 'Field')).toBeDisabled(),
  },
  {
    id: 'switch-select', fieldKey: 'until', shown: 'beta', sent: '{"op":"set","value":"stable"}',
    change: (component, page) => pick(component, page, 'stable'),
    locked: (component) => expect(control(component, 'switch', 'Field enabled')).toBeDisabled(),
  },
];

/**
 * Opens a field's editor, types `text`, and saves.
 *
 * @param component The mounted harness.
 * @param {string} text The text to type.
 */
async function typeAndSave(component, text) {
  await component.getByRole('button', { name: 'Edit Field' }).click();
  await component.getByRole('textbox', { name: 'Field' }).fill(text);
  await component.getByRole('button', { name: 'Save' }).click();
}

/**
 * Picks `option` from the list labelled `name`.
 *
 * @param component The mounted harness.
 * @param page The test's page, which holds the open list.
 * @param {string} option The option's text.
 * @param {string} [name] The list's label; Field when left out.
 */
async function pick(component, page, option, name = 'Field') {
  await component.getByRole('combobox', { name }).click();
  await page.getByRole('option', { name: option }).click();
}

/**
 * Whether a field's control can be changed: for an editable field, whether
 * it has a pencil; for the others, whether the control is enabled.
 *
 * @param component The mounted harness.
 * @param {string} role The control's role, or `button` for the pencil.
 * @param {string} name The control's label.
 */
function control(component, role, name) {
  return component.getByRole(role, { name });
}

/**
 * The value shown under the field's name.
 *
 * @param component The mounted harness.
 */
function valueOf(component) {
  return component.getByRole('group', { name: 'Field' }).getByRole('definition');
}

/**
 * The last operation the harness committed.
 *
 * @param component The mounted harness.
 */
function lastCommit(component) {
  return component.getByRole('status', { name: 'Last commit' });
}

for (const driver of DRIVERS) {
  test.describe(`the ${driver.id} component`, () => {
    test('shows its value', async ({ mount }) => {
      const component = await mount(<Harness component={driver.id} fieldKey={driver.fieldKey} />);

      await expect(valueOf(component)).toContainText(driver.shown);
    });

    test('commits a set of the new value', async ({ mount, page }) => {
      const component = await mount(<Harness component={driver.id} fieldKey={driver.fieldKey} />);

      await driver.change(component, page);

      await expect(lastCommit(component)).toHaveText(driver.sent);
    });

    test('cannot be changed when read-only', async ({ mount }) => {
      const component = await mount(<Harness component={driver.id} fieldKey={driver.fieldKey} readOnly />);

      await expect(valueOf(component)).toContainText(driver.shown);
      await driver.locked(component);
    });

    test('shows the message when a commit is refused', async ({ mount, page }) => {
      const component = await mount(<Harness component={driver.id} fieldKey={driver.fieldKey} refusing />);

      await driver.change(component, page);

      await expect(component.getByRole('alert')).toHaveText('Refused for a reason.');
    });
  });
}

test('number refuses text, a fraction for an integer, and a number out of range, without a commit', async ({ mount }) => {
  const component = await mount(<Harness component="number" fieldKey="count" />);

  const refusals = [
    ['many', 'Field needs a number.'],
    ['2.5', 'Field needs a whole number.'],
    ['11', 'Field must be at most 10.'],
    ['-1', 'Field must be at least 0.'],
  ];
  for (const [typed, message] of refusals) {
    await component.getByRole('textbox', { name: 'Field' }).or(component.getByRole('button', { name: 'Edit Field' })).first().click();
    await component.getByRole('textbox', { name: 'Field' }).fill(typed);
    await component.getByRole('button', { name: 'Save' }).click();
    await expect(component.getByRole('alert')).toHaveText(message);
  }
  await expect(lastCommit(component)).toHaveText('');
});

test('number saves a fraction where the key allows any number', async ({ mount }) => {
  const component = await mount(<Harness component="number" fieldKey="ratio" />);

  await typeAndSave(component, '0.25');

  await expect(lastCommit(component)).toHaveText('{"op":"set","value":0.25}');
});

test('select shows Not set with the default for an untouched key, and Remove clears a set one', async ({ mount }) => {
  const untouched = await mount(<Harness component="select" fieldKey="channel" values={{ title: 'Notes' }} />);
  await expect(untouched.getByRole('combobox', { name: 'Field' })).toHaveText('Not set (default: dev)');
  await untouched.unmount();

  const set = await mount(<Harness component="select" fieldKey="channel" />);
  await set.getByRole('button', { name: 'Remove Field' }).click();
  await expect(lastCommit(set)).toHaveText('{"op":"clear"}');
  await expect(set.getByRole('combobox', { name: 'Field' })).toHaveText('Cleared');
});

test('switch shows its default and Not set for an untouched key', async ({ mount }) => {
  const component = await mount(<Harness component="switch" fieldKey="enabled" values={{ title: 'Notes' }} />);

  await expect(component.getByRole('switch', { name: 'Field' })).not.toBeChecked();
  await expect(valueOf(component)).toHaveText('Not set (default: Off)');
});

test('switch-select turns off to false, and back on to the rung picked last', async ({ mount, page }) => {
  const component = await mount(<Harness component="switch-select" fieldKey="until" />);

  await pick(component, page, 'dev');
  await component.getByRole('switch', { name: 'Field enabled' }).click();
  await expect(lastCommit(component)).toHaveText('{"op":"set","value":false}');
  await expect(valueOf(component)).toHaveText('Off');
  await expect(component.getByRole('combobox', { name: 'Field' })).toHaveCount(0);

  await component.getByRole('switch', { name: 'Field enabled' }).click();
  await expect(lastCommit(component)).toHaveText('{"op":"set","value":"dev"}');
});

test('switch-select counts the string false as off, does not offer it, and turns on to the default', async ({ mount, page }) => {
  const component = await mount(<Harness component="switch-select" fieldKey="until" values={{ title: 'Notes', until: 'false' }} />);

  await expect(component.getByRole('switch', { name: 'Field enabled' })).not.toBeChecked();
  await component.getByRole('switch', { name: 'Field enabled' }).click();
  await expect(lastCommit(component)).toHaveText('{"op":"set","value":"stable"}');

  await component.getByRole('combobox', { name: 'Field' }).click();
  await expect(page.getByRole('option')).toHaveText(['dev', 'beta', 'stable']);
});

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

  await expect(lastCommit(component)).toHaveText('{"op":"clear"}');
  await expect(valueOf(component)).toHaveText('Cleared');
});

test('a required key has no Remove, and cannot be saved empty', async ({ mount }) => {
  const component = await mount(<Harness component="text" />);

  await component.getByRole('button', { name: 'Edit Field' }).click();
  await expect(component.getByRole('button', { name: 'Remove' })).toHaveCount(0);
  await component.getByRole('textbox', { name: 'Field' }).fill('  ');
  await component.getByRole('button', { name: 'Save' }).click();

  await expect(component.getByRole('alert')).toHaveText('Field cannot be empty.');
  await expect(lastCommit(component)).toHaveText('');
});

test('the help text is the binding hint when it has one, and the schema description otherwise', async ({ mount, page }) => {
  const fromSchema = await mount(<Harness component="text" />);
  await fromSchema.getByRole('button', { name: 'About Field' }).hover();
  await expect(page.getByRole('tooltip')).toHaveText('What it is called.');
  await fromSchema.unmount();

  const fromBinding = await mount(<Harness component="text" hint="The name people see." />);
  await fromBinding.getByRole('button', { name: 'About Field' }).hover();
  await expect(page.getByRole('tooltip')).toHaveText('The name people see.');
});

test('a key the schema does not describe is not shown', async ({ mount }) => {
  const component = await mount(<Harness component="text" fieldKey="gone" />);

  await expect(lastCommit(component)).toBeAttached();
  await expect(component.getByRole('group', { name: 'Field' })).toHaveCount(0);
});

test('a component that does not fit the key shows its value read-only, with an error glyph that says why', async ({ mount, page }) => {
  const component = await mount(<Harness component="text" fieldKey="count" />);

  await expect(valueOf(component)).toHaveText('3');
  await expect(component.getByRole('button', { name: 'Edit Field' })).toHaveCount(0);
  await component.getByRole('button', { name: 'About Field' }).hover();

  await expect(page.getByRole('tooltip')).toHaveText("I can't let you edit this field: the pane would save text here, but count takes a whole number. This is an unexpected bug in the Workshop plugin, not something you did. Let us know about your issue at requests@creature-workshop.com and we'll look into it.");
});

test('a component that saves several types fits only a key that accepts each of them', async ({ mount, page }) => {
  const component = await mount(<Harness component="switch-select" fieldKey="channel" />);

  await component.getByRole('button', { name: 'About Field' }).hover();

  await expect(page.getByRole('tooltip')).toContainText('the pane would save text or on or off here, but channel takes text.');
});

test('a component nobody registered says so', async ({ mount, page }) => {
  const component = await mount(<Harness component="slider" />);

  await component.getByRole('button', { name: 'About Field' }).hover();

  await expect(page.getByRole('tooltip')).toContainText('the pane asks for an editor named "slider", which doesn\'t exist.');
});
