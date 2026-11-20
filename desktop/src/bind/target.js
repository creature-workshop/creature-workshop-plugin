/**
 * @file What a binding names inside a store's view. A store is one YAML
 * file under the checkout's .ops/ folder, as workshop/synced/address.js
 * describes one. A binding is the value of a `bind` prop: a store,
 * `{kind, source}`; one record of it, with `record`; or one key of that
 * record, with `record` and `key`.
 *
 *     {kind: 'file', source: 'config/manifest.yaml', record: 'document', key: 'name'}
 *
 * names the `name` key of `.ops/config/manifest.yaml`.
 */

/**
 * The store's view narrowed to what `bind` names, as remote data. A store
 * binding gets the view as it is. A record or key binding gets the view's
 * data with the record added as `record`, or a NOT_FOUND failure when the
 * store holds no record of that id. A view that is loading or failed is
 * handed back as it is.
 *
 *     targetOf({kind: 'plan', source: 'data/plan.yaml', record: 'SHOP-1'}, {state: 'success', data: {records: [ticket], schema, git}})
 *       ->  {state: 'success', data: {records: [ticket], schema, git, record: ticket}}
 *
 * @param {{source: string, record?: string}} bind The binding.
 * @param view The store's view, as workshop/synced/view.js describes it.
 */
export function targetOf({ source, record }, view) {
  if (view.state !== 'success' || record === undefined) {
    return view;
  }
  const held = view.data.records.find((each) => each.id === record);
  if (!held) {
    return { state: 'failure', error: { message: `${source} has no record ${record}.`, code: 'NOT_FOUND', status: 404, extensions: {} } };
  }
  return { state: 'success', data: { ...view.data, record: held } };
}
