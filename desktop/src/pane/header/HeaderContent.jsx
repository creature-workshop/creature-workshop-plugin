/**
 * @file What the header holds for each state of GET /repos: nothing while
 * it loads, the failure while it failed, and once it answered, the mode
 * for where the session's folder is: holding no repository, inside one, or
 * holding some below it.
 */

import { FailureNotice } from '../../failures/FailureNotice.jsx';
import { InsideRepository } from './modes/InsideRepository.jsx';
import { NoRepositories } from './modes/NoRepositories.jsx';
import { RepositoriesBelow } from './modes/RepositoriesBelow.jsx';

/**
 * Nothing while the repositories load; "I couldn't read the repositories
 * in this folder." with why, what to try and Try again when reading them failed; and
 * otherwise the mode for where the session's folder is.
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
  const Mode = modeFor(repos.data);
  return <Mode />;
}

/**
 * The header's mode for an answer of GET /repos: NoRepositories when it
 * lists none, InsideRepository when the session's folder is inside one,
 * and RepositoriesBelow when the folder is inside none and holds some
 * below it, even only one.
 *
 * @param listing GET /repos's answer.
 * @param {object[]} listing.repos The repositories the session's folder holds.
 * @param {boolean} listing.inside Whether the session's folder is inside a repository.
 */
function modeFor({ repos, inside }) {
  if (repos.length === 0) {
    return NoRepositories;
  }
  return inside ? InsideRepository : RepositoriesBelow;
}
