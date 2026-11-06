/**
 * @file One tool of the toolchain: a dot for installed or missing, the
 * tool, its version and its channel.
 */

export function Row({ tool, version, channel, installed }) {
  return (
    <div className="flex items-center gap-2 py-0.5 text-xs">
      <span style={{ color: installed ? '#3fb950' : '#f85149' }}>{installed ? '●' : '○'}</span>
      <span className="flex-1 font-medium">{tool}</span>
      <span className="text-(--ui-text-tertiary)">{version}</span>
      <span className="text-(--ui-text-tertiary)">{channel}</span>
    </div>
  );
}
