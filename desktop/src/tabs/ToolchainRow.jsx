/**
 * @file One tool of the toolchain: a dot for installed or missing, the
 * tool, its version and its channel.
 */

/**
 * One row of the Toolchain tab.
 * @param props The component's props, one row of install --check.
 * @param props.tool The tool's name.
 * @param props.version The declared version.
 * @param props.channel The channel the tool comes from.
 * @param props.installed Whether the tool is installed.
 */
export function ToolchainRow({ tool, version, channel, installed }) {
  return (
    <div className="flex items-center gap-2 py-0.5 text-xs">
      <span style={{ color: installed ? '#3fb950' : '#f85149' }}>{installed ? '●' : '○'}</span>
      <span className="flex-1 font-medium">{tool}</span>
      <span className="text-(--ui-text-tertiary)">{version}</span>
      <span className="text-(--ui-text-tertiary)">{channel}</span>
    </div>
  );
}
