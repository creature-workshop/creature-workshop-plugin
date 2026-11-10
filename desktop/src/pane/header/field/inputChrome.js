/**
 * @file The colors of Desktop's input chrome, for the header's own boxes and
 * lines that sit beside its selectors.
 */

/**
 * The border color Desktop gives `.desktop-input-chrome`, its inputs and
 * selects, so a line drawn next to a selector is exactly as light as the
 * selector's outline in every theme.
 */
export const INPUT_STROKE = 'color-mix(in srgb, var(--dt-composer-ring) var(--dt-input-border), transparent)';

/** The background Desktop gives `.desktop-input-chrome`, so a box beside a selector is filled like it. */
export const INPUT_FILL = 'color-mix(in srgb, var(--dt-card) var(--dt-input-bg), transparent)';

/** The inset shadow Desktop gives `.desktop-input-chrome`, which darkens the inside of its inputs and selects. */
export const INPUT_INSET = 'var(--dt-input-inset)';
