/**
 * @file The header along the top of the pane: the git repositories the
 * session holds, in one of three modes. With none it says so; with one it
 * shows its name and its state; with several it offers a selector, and the
 * state of the one selected.
 */

import { cn } from '@hermes/plugin-sdk';
import { useWorkshop } from '../../workshop/WorkshopProvider.jsx';
import { HeaderContent } from './HeaderContent.jsx';

/** The header's height, so the line under it sits where a line of text would end while it is still loading. */
const HEADER_STYLE = { minHeight: '1.75rem' };

/**
 * The header: a banner region along the top of the pane, set apart from the
 * pane's body by Desktop's faintest fill, the wash its own kanban panels
 * use, with the line under it in the app's tertiary stroke. The role is set
 * by hand because a header inside a section has none of its own. It is empty
 * until the backend has said which repositories the session holds, and
 * says what went wrong, with Try again, when it could not say.
 */
export function Header() {
  const { repos, retry } = useWorkshop();

  return (
    <header
      role="banner"
      aria-label="Project"
      className={cn(
        'workshop-header',
        'flex',
        'min-w-0',
        'items-end',
        'gap-2',
        'border-b',
        'border-(--ui-stroke-tertiary)',
        'bg-(--ui-bg-quinary)',
        'px-2',
        'py-2',
        'text-[0.6875rem]',
      )}
      style={HEADER_STYLE}
    >
      <HeaderContent repos={repos} onRetry={() => retry('repos')} />
    </header>
  );
}
