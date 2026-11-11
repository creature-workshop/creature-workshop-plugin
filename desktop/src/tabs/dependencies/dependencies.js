/**
 * @file The Dependencies tab's data: the tools a project declares, grouped
 * by the channel that installs them, each with whether it is installed.
 */

/** What the tab can say about one tool. */
export const STATUS = Object.freeze({ installed: 'installed', missing: 'missing', checking: 'checking', unknown: 'unknown' });

/**
 * The declared tools grouped by channel, in the order the declaration
 * names the channels and the tools, each with its status.
 *
 *     channelsOf([{channel: 'npm', tool: 'pnpm', version: '12'}], check)
 *       ->  [{channel: 'npm', tools: [{tool: 'pnpm', version: '12', status: 'installed'}]}]
 *
 * @param {{channel: string, tool: string, version: string}[]} declared The tools GET /project lists as declared.
 * @param check The toolchain check, as remote data holding GET /project's `toolchain`.
 *
 * @returns {{channel: string, tools: {tool: string, version: string, status: string}[]}[]} The groups.
 */
export function channelsOf(declared, check) {
  const groups = new Map();
  for (const { channel, tool, version } of declared) {
    const tools = groups.get(channel) ?? [];
    groups.set(channel, [...tools, { tool, version, status: statusOf(tool, check) }]);
  }
  return [...groups].map(([channel, tools]) => ({ channel, tools }));
}

/**
 * Whether the tool is installed, as far as the check says: checking while
 * the check runs, installed or missing from its row, and unknown when the
 * check failed or has no row for the tool.
 *
 * @param {string} tool The tool's name.
 * @param check The toolchain check, as remote data.
 *
 * @returns {string} One of STATUS.
 */
export function statusOf(tool, check) {
  if (check.state === 'loading') {
    return STATUS.checking;
  }
  const row = (check.data?.rows ?? []).find((each) => each.tool === tool);
  if (!row) {
    return STATUS.unknown;
  }
  return row.installed ? STATUS.installed : STATUS.missing;
}

/**
 * What the tab says above the groups: how many dependencies there are, and
 * how many are missing once that is known.
 *
 *     summaryOf(groups)  ->  '5 dependencies, 1 missing'
 *
 * @param {{tools: {status: string}[]}[]} groups The groups, as channelsOf answers them.
 *
 * @returns {string} The line.
 */
export function summaryOf(groups) {
  const statuses = groups.flatMap((group) => group.tools.map((tool) => tool.status));
  const count = `${statuses.length} ${statuses.length === 1 ? 'dependency' : 'dependencies'}`;
  if (statuses.some((status) => status === STATUS.checking || status === STATUS.unknown)) {
    return count;
  }
  const missing = statuses.filter((status) => status === STATUS.missing).length;
  return `${count}, ${missing === 0 ? 'all installed' : `${missing} missing`}`;
}

/**
 * Whether the check finished without saying anything about any tool, so
 * the tab cannot tell which are installed.
 *
 * @param check The toolchain check, as remote data.
 * @param {{tools: {status: string}[]}[]} groups The groups, as channelsOf answers them.
 *
 * @returns {boolean} Whether to say the check told nothing.
 */
export function uncheckable(check, groups) {
  return check.state === 'success' && groups.length > 0 && groups.every((group) => group.tools.every((tool) => tool.status === STATUS.unknown));
}
