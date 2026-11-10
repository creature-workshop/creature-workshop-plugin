/**
 * @file What the header holds for each state of GET /repos: nothing while
 * it loads, the failure while it failed, and the mode for the number of
 * repositories once it answered.
 */

import { FailureNotice } from '../../failures/FailureNotice.jsx';
import { MultiRepoHeader } from './MultiRepoHeader.jsx';
import { NoRepoHeader } from './NoRepoHeader.jsx';
import { SingleRepoHeader } from './SingleRepoHeader.jsx';

/**
 * Nothing while the repositories load; "I couldn't read the repositories
 * in this folder." with why, what to try and Try again when reading them failed; and
 * otherwise the mode for how many there are: none, one, or several.
 *
 * @param props The component's props.
 * @param props.repos GET /repos's answer, as remote data.
 * @param {() => void} props.onRetry Reads the repositories again.
 */
export function HeaderContent({ repos, onRetry }) {
  if (repos.state === 'failure') {
    return <FailureNotice what="I couldn't read the repositories in this folder." error={repos.error} onRetry={onRetry} />;
  }
  if (repos.state !== 'success') {
    return null;
  }
  const Mode = modeFor(repos.data.repos.length);
  return <Mode />;
}

/**
 * The header's mode for a number of repositories.
 *
 * @param count How many repositories the session holds.
 */
function modeFor(count) {
  return [NoRepoHeader, SingleRepoHeader][count] ?? MultiRepoHeader;
}
