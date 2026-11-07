/**
 * @file Reading the toolchain out of a loaded project. ToolchainTab and ToolchainChip
 * call toolchainSummary while rendering.
 */

/**
 * The rows of the toolchain and how many of them are installed.
 * @param project The loaded project.
 */
export function toolchainSummary(project) {
  const rows = project.toolchain && project.toolchain.rows ? project.toolchain.rows : [];
  const installed = rows.filter((row) => row.installed).length;
  return { rows, installed, total: rows.length };
}
