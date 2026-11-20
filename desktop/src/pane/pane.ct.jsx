/**
 * @file What a user sees in the pane: a region named Workshop, with a header
 * along its top and a footer along its bottom that says which build of the
 * plugin this is and which checkout it came from, keeping the branch alone
 * when the pane is too narrow for both. Between them, when the selected
 * repository is a shellops project, sit the Workshop tabs with the Project
 * Info tab open; when its branch has no workshop, a notice with Initialize workshop. The tests mount the pane's stories
 * and read the pane by role and by text, never by a test id.
 */

import { test, expect } from '@playwright/experimental-ct-react';
import { Adopted, FailingOnce, NotAdopted, OnMain, OutsideGit, Unapproved, WorkshopDeleted } from './WorkshopPane.story.jsx';

/**
 * What the footer shows: its text with the hidden measuring copy left out.
 *
 * @param component The mounted pane.
 */
function shown(component) {
  return component.getByRole('contentinfo').evaluate((footer) => {
    const measure = footer.querySelector('[aria-hidden]');
    return footer.textContent.replace(measure.textContent, '').trim();
  });
}

test('the header runs along the top of the pane, above the footer', async ({ mount }) => {
  const component = await mount(<OnMain />);

  const header = component.getByRole('banner', { name: 'Project' });
  await expect(header).toHaveText('No repositories detected');
  const top = await header.boundingBox();
  const bottom = await component.getByRole('contentinfo').boundingBox();
  expect(top.y + top.height).toBeLessThanOrEqual(bottom.y);
});

test('the footer shows the version and the branch', async ({ mount }) => {
  const component = await mount(<OnMain />);

  await expect(component.getByRole('region', { name: 'Workshop' })).toBeVisible();
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});

test('the footer shows the version alone outside git', async ({ mount }) => {
  const component = await mount(<OutsideGit />);

  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9');
});

test('the footer keeps the branch and drops the version when the pane is too narrow for both', async ({ mount }) => {
  const component = await mount(<OnMain width={90} />);

  await expect.poll(() => shown(component)).toBe('main');

  await component.update(<OnMain width={320} />);
  await expect.poll(() => shown(component)).toBe('0.1.0-dev.9 · main');
});

test('a shellops project opens on the Project Info tab, between the header and the footer', async ({ mount }) => {
  const component = await mount(<Adopted />);

  const strip = component.getByRole('tablist', { name: 'Workshop tabs' });
  await expect(strip.getByRole('tab', { name: 'Project Info', selected: true })).toBeVisible();
  const header = await component.getByRole('banner', { name: 'Project' }).boundingBox();
  const tabs = await strip.boundingBox();
  const footer = await component.getByRole('contentinfo').boundingBox();
  expect(header.y + header.height).toBeLessThanOrEqual(tabs.y);
  expect(tabs.y + tabs.height).toBeLessThanOrEqual(footer.y);
});

test('the Project Info tab shows what the manifest says and the releases of the lock', async ({ mount }) => {
  const component = await mount(<Adopted latest="0.1.0-dev.12" stable="0.0.0" />);

  const panel = component.getByRole('tabpanel', { name: 'Project Info' });
  await expect(panel.getByRole('term')).toHaveText(['Name', 'Description', 'Command', 'Organization', 'Repository', 'Latest', 'Stable']);
  await expect(panel.getByRole('definition')).toHaveText(['Notes', 'Notes, kept in git.', 'notes', 'someone', 'notes', '0.1.0-dev.12', '0.0.0']);
});

test('a release the lock does not record reads None yet', async ({ mount }) => {
  const component = await mount(<Adopted latest="" stable="" />);

  const panel = component.getByRole('tabpanel', { name: 'Project Info' });
  await expect(panel.getByRole('definition').filter({ hasText: 'None yet' })).toHaveCount(2);
});

test('a branch without a workshop says so in place of the tabs', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await expect(component.getByRole('banner', { name: 'Project' })).toContainText('notes');
  await expect(component.getByRole('status')).toContainText("notes doesn't have a workshop yet.");
  await expect(component.getByRole('status')).toContainText('Its branch has no .ops/config');
  await expect(component.getByRole('tablist')).toHaveCount(0);
});

test('Initialize workshop opens a form filled from the folder, its remote and the agent, with the organization empty and the commit off', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });

  await expect(form.getByRole('textbox', { name: 'Project Name' })).toHaveValue('notes');
  await expect(form.getByRole('textbox', { name: 'Description' })).toHaveValue('Notes kept in git.');
  await expect(form.getByRole('textbox', { name: 'Command' })).toHaveValue('notes');
  await expect(form.getByRole('textbox', { name: 'Organization' })).toHaveValue('');
  await expect(form.getByRole('textbox', { name: 'Repository' })).toHaveValue('notes');
  await expect(form.getByRole('switch', { name: 'Commit the workshop files to main' })).not.toBeChecked();
  await expect(form.getByText('Model suggestion')).toHaveCount(2);
});

test('each field of the Set up shop form says what it is for in its (i)', async ({ mount, page }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });
  await form.getByRole('button', { name: 'About Command' }).hover();

  await expect(page.getByRole('tooltip')).toHaveText('The command-line program the project ships. Leave it empty if it ships none.');
  await expect(form.getByRole('button', { name: /^About / })).toHaveCount(6);
});

test('without a guess from the agent, the description and the command start empty and unmarked', async ({ mount }) => {
  const component = await mount(<NotAdopted unguessed />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });

  await expect(form.getByRole('textbox', { name: 'Description' })).toHaveValue('');
  await expect(form.getByRole('textbox', { name: 'Command' })).toHaveValue('');
  await expect(form.getByText('Model suggestion')).toHaveCount(0);
});

test('Confirm sends the manifest as the user left it and the commit switch, and the tabs replace the form', async ({ mount }) => {
  const sent = [];
  const component = await mount(<NotAdopted onAdopt={(body) => sent.push(body)} />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });
  await form.getByRole('textbox', { name: 'Project Name' }).fill('Notes');
  await form.getByRole('textbox', { name: 'Description' }).fill('Notes, kept in git.');
  await form.getByRole('textbox', { name: 'Organization' }).fill('someone');
  await form.getByRole('switch', { name: 'Commit the workshop files to main' }).click();
  await form.getByRole('button', { name: 'Confirm' }).click();

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect.poll(() => sent).toEqual([{
    root: '/home/someone/notes',
    manifest: { name: 'Notes', description: 'Notes, kept in git.', 'command-name': 'notes', org: 'someone', repo: 'notes' },
    commit: true,
  }]);
});

test('the form says what completing setup agrees to, above its buttons, and has no switch for it', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });

  await expect(form.getByText('By completing setup, you agree to let Creature Workshop run commands to manage this repository.')).toBeVisible();
  await expect(form.getByRole('switch')).toHaveCount(1);
});

test('the notice sits with the buttons, apart from the last switch, and Confirm is the wider button', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });
  const last = await form.getByRole('switch').boundingBox();
  const notice = await form.getByText('By completing setup').boundingBox();
  const confirm = await form.getByRole('button', { name: 'Confirm' }).boundingBox();
  const cancel = await form.getByRole('button', { name: 'Cancel' }).boundingBox();

  const above = notice.y - (last.y + last.height);
  const below = confirm.y - (notice.y + notice.height);
  expect(below).toBe(8);
  expect(above).toBeGreaterThanOrEqual(2 * below);
  expect(confirm.width).toBeGreaterThanOrEqual(96);
  expect(confirm.width).toBeGreaterThan(cancel.width);
});

test('the description is a field of several lines, and the other fields are one line', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });

  await expect(form.getByRole('textbox', { name: 'Description' })).toHaveJSProperty('tagName', 'TEXTAREA');
  await expect(form.getByRole('textbox', { name: 'Project Name' })).toHaveJSProperty('tagName', 'INPUT');
});

test('Confirm adds the project to the approved projects and keeps the others', async ({ mount }) => {
  const written = [];
  const component = await mount(<NotAdopted approved={['/home/someone/other']} onApprove={(roots) => written.push(roots)} />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });
  await form.getByRole('button', { name: 'Confirm' }).click();

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect.poll(() => written).toEqual([['/home/someone/other', '/home/someone/notes']]);
});

test('when Hermes does not save the approval, the pane says so and sets up nothing', async ({ mount }) => {
  const sent = [];
  const component = await mount(<NotAdopted unsaved onAdopt={(body) => sent.push(body)} />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  const form = component.getByRole('form', { name: 'Set up shop' });
  await form.getByRole('button', { name: 'Confirm' }).click();

  const alert = component.getByRole('alert');
  await expect(alert).toContainText("I couldn't record your approval of notes, so I haven't set up shop yet.");
  await expect(alert).toContainText("Hermes didn't save the approved_projects setting: the gateway is restarting");
  await expect(alert.getByRole('button', { name: 'Try again' })).toBeVisible();
  expect(sent).toEqual([]);
});

test('a project that is set up and not approved shows only the approval notice, centred, and no tabs', async ({ mount }) => {
  const component = await mount(<Unapproved />);

  const notice = component.getByRole('status').filter({ hasText: 'Approval needed for notes.' });
  await expect(notice).toHaveText('Approval needed for notes.By approving, you agree to let Creature Workshop run commands to manage this repository.Approve project');
  await expect(notice.getByRole('button', { name: 'Approve project' })).toBeVisible();
  await expect(component.getByRole('tablist')).toHaveCount(0);
  await expect(notice).toHaveCSS('text-align', 'center');
  await expect(notice).toHaveCSS('justify-content', 'center');
  await expect(notice).toHaveCSS('align-items', 'center');
});

test('Approve project adds the project to the approved projects, keeps the others, and the tabs replace the notice', async ({ mount }) => {
  const written = [];
  const component = await mount(<Unapproved approved={['/home/someone/other']} onApprove={(roots) => written.push(roots)} />);

  await component.getByRole('button', { name: 'Approve project' }).click();

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect(component.getByText('Approval needed for notes.')).toHaveCount(0);
  expect(written).toEqual([['/home/someone/other', '/home/someone/notes']]);
});

test('when Hermes does not save the approval, the notice says so with Try again', async ({ mount }) => {
  const component = await mount(<Unapproved unsaved />);

  await component.getByRole('button', { name: 'Approve project' }).click();

  const alert = component.getByRole('alert');
  await expect(alert).toContainText("I couldn't record your approval of notes.");
  await expect(alert).toContainText("Hermes didn't save the approved_projects setting: the gateway is restarting");
  await expect(alert.getByRole('button', { name: 'Try again' })).toBeVisible();
});

test('an approved project shows no approval notice', async ({ mount }) => {
  const component = await mount(<Adopted />);

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect(component.getByRole('button', { name: 'Approve project' })).toHaveCount(0);
});

test('a checkout with no workshop shows its notice alone and centred, as the approval notice is', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  const notice = component.getByRole('status').filter({ hasText: "notes doesn't have a workshop yet." });
  await expect(notice.getByRole('button', { name: 'Initialize workshop' })).toBeVisible();
  await expect(notice).toContainText("Its branch has no .ops/config, so there's nothing here for me to show.");
  await expect(notice).not.toContainText('Another branch');
  await expect(notice).toHaveCSS('padding', '24px');
  await expect(notice).toHaveCSS('text-align', 'center');
  await expect(notice).toHaveCSS('justify-content', 'center');
  await expect(notice).toHaveCSS('align-items', 'center');
});

test('Cancel goes back to the notice', async ({ mount }) => {
  const component = await mount(<NotAdopted />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  await component.getByRole('button', { name: 'Cancel' }).click();

  await expect(component.getByRole('status')).toContainText("notes doesn't have a workshop yet.");
});

test('a refused adoption says so, and Try again sends the same answers', async ({ mount }) => {
  const sent = [];
  const component = await mount(<NotAdopted fails onAdopt={(body) => sent.push(body)} />);

  await component.getByRole('button', { name: 'Initialize workshop' }).click();
  await component.getByRole('form', { name: 'Set up shop' }).getByRole('button', { name: 'Confirm' }).click();
  await expect(component.getByRole('alert')).toContainText("I couldn't set up shop in notes.");
  await component.getByRole('button', { name: 'Try again' }).click();

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect.poll(() => sent.length).toBe(2);
  expect(sent[1]).toEqual(sent[0]);
});

test('a set-up checkout shows the tabs and no setup notice', async ({ mount }) => {
  const component = await mount(<Adopted />);

  await expect(component.getByRole('tablist')).toBeVisible();
  await expect(component.getByText("doesn't have a workshop yet")).toHaveCount(0);
});

test('a failed read of the setup says so, and Try again reads it again', async ({ mount }) => {
  const component = await mount(<FailingOnce path="/project/setup" kind="unreachable" />);

  await expect(component.getByRole('alert')).toContainText("I couldn't tell whether notes is set up.");
  await component.getByRole('button', { name: 'Try again' }).click();

  await expect(component.getByRole('tablist')).toBeVisible();
});

test('a failed read of the repositories says what happened, why and what to try, and Try again reads them again', async ({ mount }) => {
  const component = await mount(<FailingOnce path="/repos?" kind="no-route" />);
  const header = component.getByRole('banner', { name: 'Project' });

  await expect(header.getByRole('alert')).toContainText("I couldn't read the repositories in this folder.");
  await expect(header.getByRole('alert')).toContainText('older than the pane');
  await expect(header.getByRole('alert')).toContainText('Quit Hermes from the tray and open it again');
  await header.getByRole('button', { name: 'Try again' }).click();

  await expect(header).toContainText('notes');
  await expect(header.getByRole('alert')).toHaveCount(0);
});

test('a failed read of the project says so in place of the tabs, with Report it for a bug and the details on request', async ({ mount }) => {
  const component = await mount(<FailingOnce path="/project?" kind="internal" />);
  const alert = component.getByRole('alert');

  await expect(alert).toContainText("I couldn't read the project in");
  await expect(alert).toContainText("ran into an unexpected bug. This isn't something you did.");
  await expect(alert.getByRole('link', { name: 'Report it' })).toHaveAttribute('href', /^mailto:requests@creature-workshop\.com\?subject=Workshop%20plugin%3A%20I%20couldn't%20read%20the%20project/);
  await expect(alert).not.toContainText("KeyError: 'root'");
  await alert.getByRole('button', { name: 'Show details' }).click();
  await expect(alert).toContainText("message: KeyError: 'root'");
  await alert.getByRole('button', { name: 'Try again' }).click();

  await expect(component.getByRole('tab', { name: 'Project Info' })).toBeVisible();
});

test('a failed read of the version says the Workshop plugin version is unavailable, with why in the (i)', async ({ mount, page }) => {
  const component = await mount(<FailingOnce path="/about" kind="unreachable" />);
  const footer = component.getByRole('contentinfo');

  await expect(footer).toContainText('Workshop plugin version unavailable');
  await footer.getByRole('button', { name: 'About Version' }).hover();

  await expect(page.getByRole('tooltip')).toContainText("The Workshop plugin's backend didn't answer.");
});

test('a failed read of the manifest says so in its group, and Try again shows the fields', async ({ mount }) => {
  const component = await mount(<FailingOnce path="/store/query" kind="unreachable" />);
  const manifest = component.getByRole('region', { name: 'Manifest' });

  await expect(manifest.getByRole('alert')).toContainText("I couldn't read the Manifest fields from config/manifest.yaml.");
  await manifest.getByRole('button', { name: 'Try again' }).click();

  await expect(manifest.getByRole('group', { name: 'Name' })).toContainText('Notes');
});

test('a workshop deleted outside the pane gives way to Initialize workshop within 5 seconds', async ({ mount, page }) => {
  await page.clock.install();
  const component = await mount(<WorkshopDeleted />);

  await expect(component.getByRole('tab', { name: 'Project Info' })).toBeVisible();
  await page.clock.runFor(5_000);

  await expect(component.getByRole('button', { name: 'Initialize workshop' })).toBeVisible();
  await expect(component.getByRole('tab', { name: 'Project Info' })).toHaveCount(0);
});
