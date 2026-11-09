/**
 * @file A repository's state as a shell prompt shows it: the branch, or the
 * short commit in brackets when HEAD is detached, then a mark and a count
 * for each thing that is not clean, or a tick when nothing is. The words
 * say the same in full, for the tooltip.
 */

/** The marks for the counts, in the order the prompt shows them, with the word each stands for. */
const MARKS = [
  { key: 'ahead', mark: '↑', word: 'ahead' },
  { key: 'behind', mark: '↓', word: 'behind' },
  { key: 'staged', mark: '+', word: 'staged' },
  { key: 'modified', mark: '~', word: 'modified' },
  { key: 'untracked', mark: '?', word: 'untracked' },
  { key: 'conflicted', mark: '!', word: 'conflicted' },
];

/** The mark for a repository with nothing to report. */
const CLEAN = '✓';

/** What the prompt says when git could not read the repository. */
const UNREADABLE = 'unreadable';

/**
 * The prompt for a repository's state.
 *
 * @param status The backend's answer to GET /repos/status.
 *
 * @returns The prompt: `main ↑2 +1 ?3`, `(abc1234) ✓`, or `unreadable`.
 */
export function promptText(status) {
  if (!status.ok) {
    return UNREADABLE;
  }

  const marks = marksOf(status).map(({ mark, count }) => `${mark}${count}`);
  return [branchText(status), ...(marks.length > 0 ? marks : [CLEAN])].join(' ');
}

/**
 * The prompt in words.
 *
 * @param status The backend's answer to GET /repos/status.
 *
 * @returns The words: `main, 2 ahead, 1 staged`, or `main, clean`.
 */
export function promptWords(status) {
  if (!status.ok) {
    return 'git could not read this repository';
  }

  const words = marksOf(status).map(({ word, count }) => `${count} ${word}`);
  return [branchWords(status), ...(words.length > 0 ? words : ['clean'])].join(', ');
}

/**
 * The marks whose count is above zero, each with its count.
 *
 * @param status The backend's answer to GET /repos/status.
 */
function marksOf(status) {
  return MARKS.filter(({ key }) => status[key] > 0).map((entry) => ({ ...entry, count: status[entry.key] }));
}

/**
 * The branch as the prompt shows it: its name, or the short commit in brackets when HEAD is detached.
 *
 * @param status The backend's answer to GET /repos/status.
 */
function branchText(status) {
  return status.detached ? `(${status.branch})` : status.branch;
}

/**
 * The branch in words.
 *
 * @param status The backend's answer to GET /repos/status.
 */
function branchWords(status) {
  return status.detached ? `detached at ${status.branch}` : status.branch;
}
