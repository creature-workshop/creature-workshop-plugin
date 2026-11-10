/**
 * @file The Project Info tab's binding to the project's manifest: the keys
 * of .ops/config/manifest.yaml it shows and edits, in order, each with the
 * component that shows it.
 */

import { register } from '../../inspector/bindings.js';

/** The manifest keys Project Info shows, registered with the inspector. */
export const MANIFEST = register({
  id: 'project-info/manifest',
  title: 'Manifest',
  collection: { kind: 'file', source: 'config/manifest.yaml' },
  record: 'document',
  fields: [
    { key: 'name', component: 'text', label: 'Name' },
    { key: 'description', component: 'multiline', label: 'Description' },
    { key: 'command-name', component: 'text', label: 'Command' },
    { key: 'org', component: 'text', label: 'Organization' },
    { key: 'repo', component: 'text', label: 'Repository' },
  ],
});
