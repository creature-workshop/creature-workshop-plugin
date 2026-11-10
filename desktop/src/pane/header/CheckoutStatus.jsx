/**
 * @file A repository's state in the header, the way a shell prompt shows it,
 * read again on the pane's refresh interval.
 */

import { cn, Tip } from '@hermes/plugin-sdk';
import { client } from '../../client/index.js';
import { describe } from '../../failures/describe.js';
import { usePolled } from '../../hooks/usePolled.js';
import { promptText, promptWords } from '../../repos/prompt.js';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';

/** What the header shows when GET /repos/status failed. */
const UNAVAILABLE = 'state unavailable';

/** One line as tall as the header's extra-small selectors, so the state sits level with their text; inline because Desktop's stylesheet has no class for it. */
const STATUS_STYLE = { lineHeight: '1.375rem' };

/**
 * The prompt for the repository at root, pushed to the header's right
 * edge, with the same in words in Desktop's tooltip, the one the (i)s use,
 * and for assistive technology, which reads the words instead of the
 * symbols; nothing until the backend has answered. When the call failed it
 * shows "state unavailable", and its tooltip says why and what to try.
 *
 * @param props The component's props.
 * @param props.root The repository's root.
 */
export function CheckoutStatus({ root }) {
  const { repos } = useWorkshop();
  const result = usePolled(() => client.repoStatus(root), repos.data.refresh_seconds, root);
  if (!result) {
    return null;
  }
  const { text, words } = shown(result);

  return (
    <Tip label={words}>
      <span
        className={cn(
          'workshop-repo-status',
          'ml-auto',
          'shrink-0',
          'text-(--ui-text-tertiary)',
        )}
        style={STATUS_STYLE}
      >
        <span aria-hidden="true" className={cn('workshop-repo-status-prompt')}>{text}</span>
        <span className={cn('workshop-repo-status-words', 'sr-only')}>{words}</span>
      </span>
    </Tip>
  );
}

/**
 * The prompt and its words for a result: the repository's state when the
 * call succeeded, or "state unavailable" and why when it failed.
 *
 * @param result GET /repos/status's result.
 *
 * @returns {{text: string, words: string}} What the header shows, and its tooltip.
 */
function shown(result) {
  if (result.ok) {
    return { text: promptText(result.data), words: promptWords(result.data) };
  }
  const { why, hint } = describe(result.error);
  return { text: UNAVAILABLE, words: `I couldn't read this repository's state. ${why} ${hint}` };
}
