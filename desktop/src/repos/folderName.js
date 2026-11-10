/**
 * @file The name a checkout goes by: the last part of its path.
 */

/**
 * The last part of a path, the name a repository or worktree goes by.
 *
 *     folderName('/home/someone/notes/')  ->  'notes'
 *
 * @param {string} path The checkout's root.
 */
export function folderName(path) {
  return path.split('/').filter(Boolean).pop() ?? path;
}
