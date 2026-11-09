/**
 * @file A titled group of Project Info fields, such as Manifest or Versions,
 * that folds up. Its heading looks like the section headings of Desktop's
 * chat sidebar, such as Pinned and Projects.
 */

import { cn, Codicon } from '@hermes/plugin-sdk';
import { useState } from 'react';

/**
 * A region named `title`. Its heading is a button that folds the fields
 * away and unfolds them again; the fields start unfolded. The heading shows
 * the sidebar's dithered square, the title in the theme's primary color, and
 * a caret that appears on hover or focus, pointing down while the fields
 * show and right while they are folded away. Focused, it gets the same focus
 * ring as Desktop's buttons. The button has 4px of padding around its
 * content, taken back with a negative margin, so the ring clears the square
 * and the caret while the title stays in line with the field names.
 *
 * @param props The component's props.
 * @param {string} props.title The group's name.
 * @param props.children The fields, each a Field or an EditableField.
 */
export function FieldGroup({ title, children }) {
  const [open, setOpen] = useState(true);

  return (
    <section aria-label={title} className={cn('workshop-field-group', 'flex', 'flex-col', 'gap-2')}>
      <h3 className={cn('workshop-field-group-title', 'flex')}>
        <button
          type="button"
          aria-expanded={open}
          onClick={() => setOpen(!open)}
          className={cn(
            'group/section-label',
            'flex',
            'w-fit',
            'min-w-0',
            'items-center',
            'gap-1',
            '-mx-1',
            '-my-1',
            'px-1',
            'py-1',
            'rounded-sm',
            'bg-transparent',
            'leading-none',
            'focus-visible:outline-hidden',
            'focus-visible:ring-[0.1875rem]',
            'focus-visible:ring-ring/50',
          )}
        >
          <span
            className={cn(
              'workshop-field-group-label',
              'flex',
              'min-w-0',
              'items-center',
              'gap-2',
              'text-[0.64rem]',
              'font-semibold',
              'uppercase',
              'tracking-[0.16em]',
              'text-(--theme-primary)',
            )}
          >
            <span aria-hidden="true" className={cn('workshop-field-group-dot', 'dither', 'inline-block', 'size-2', 'shrink-0', 'rounded-[1px]')} />
            {title}
          </span>
          <Codicon
            name="chevron-right"
            className={cn(
              'shrink-0',
              'text-(--ui-text-tertiary)',
              'opacity-0',
              'transition',
              'group-hover/section-label:opacity-100',
              'group-focus-visible/section-label:opacity-100',
              open && 'rotate-90',
            )}
          />
        </button>
      </h3>
      {open && <dl className={cn('workshop-field-list', 'flex', 'flex-col', 'gap-3')}>{children}</dl>}
    </section>
  );
}
