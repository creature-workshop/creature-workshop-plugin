/**
 * @file Loading what the plugin is through the backend: a plain function with
 * no React in it. The pane's effect calls loadAbout once and keeps what it
 * returns.
 */

/**
 * The backend's answer to GET /about: {version, branch}, or both empty when
 * the call itself failed, so the footer draws nothing rather than an error.
 *
 * @param rest The backend call, taking a path under the plugin's API.
 */
export async function loadAbout(rest) {
  try {
    return await rest('/about');
  } catch {
    return { version: '', branch: '' };
  }
}
