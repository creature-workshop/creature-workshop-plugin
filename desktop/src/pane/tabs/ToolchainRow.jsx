/**
 * @file One tool of the toolchain: a dot for installed or missing, the
 * tool, its version and its channel.
 */
import { INSTALLED, MISSING } from '../../theme.js';

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
    <div className="workshop-tool flex items-center gap-2 py-0.5 text-xs">
      <span className="workshop-tool-state" style={{ color: installed ? INSTALLED : MISSING }}>{installed ? '●' : '○'}</span>
      <span className="workshop-tool-name flex-1 font-medium">{tool}</span>
      <span className="workshop-tool-version text-(--ui-text-tertiary)">{version}</span>
      <span className="workshop-tool-channel text-(--ui-text-tertiary)">{channel}</span>
    </div>
  );
}
