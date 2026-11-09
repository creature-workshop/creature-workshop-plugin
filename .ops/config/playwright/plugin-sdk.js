/**
 * @file A stand-in for `@hermes/plugin-sdk` in the pane's component tests,
 * which run in Playwright's own page and not in Desktop: the parts of the
 * SDK the components under test import, built on the radix-ui primitives
 * Desktop's own components are built on, without Desktop's styling, and the
 * same clsx and tailwind-merge that Desktop's cn joins classes with. The
 * Playwright config resolves the SDK's name to this file. Like the SDK, it
 * exports one component for each of Desktop's, so it holds several.
 */

import { clsx } from 'clsx';
import { createElement } from 'react';
import { Select as Primitive, Tabs as TabsPrimitive } from 'radix-ui';
import { twMerge } from 'tailwind-merge';

/**
 * Desktop's cn: joins class names, leaving out the falsy ones, and keeps the
 * last of any Tailwind classes that set the same property.
 *
 * @param inputs Class names, lists of them, or objects from class name to whether it applies.
 */
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

/**
 * Desktop's Select: the root of a radix select.
 *
 * @param props The select's props.
 */
export function Select(props) {
  return createElement(Primitive.Root, props);
}

/**
 * Desktop's SelectTrigger: the button that opens the select.
 *
 * @param props The trigger's props.
 */
export function SelectTrigger(props) {
  return createElement(Primitive.Trigger, props);
}

/**
 * Desktop's SelectValue: the picked item's text, or the placeholder.
 *
 * @param props The value's props.
 */
export function SelectValue(props) {
  return createElement(Primitive.Value, props);
}

/**
 * Desktop's SelectContent: the list, in a portal, placed under the trigger.
 *
 * @param props The content's props.
 * @param props.children The items.
 */
export function SelectContent({ children, ...props }) {
  return createElement(Primitive.Portal, null, createElement(Primitive.Content, { position: 'popper', ...props }, createElement(Primitive.Viewport, null, children)));
}

/**
 * Desktop's SelectItem: one option, with its text.
 *
 * @param props The item's props.
 * @param props.children The item's text.
 */
export function SelectItem({ children, ...props }) {
  return createElement(Primitive.Item, props, createElement(Primitive.ItemText, null, children));
}

/**
 * Desktop's Tabs: the root of radix tabs.
 *
 * @param props The tabs' props.
 */
export function Tabs(props) {
  return createElement(TabsPrimitive.Root, props);
}

/**
 * Desktop's TabsList: the strip that holds the triggers.
 *
 * @param props The list's props.
 */
export function TabsList(props) {
  return createElement(TabsPrimitive.List, props);
}

/**
 * Desktop's TabsTrigger: one tab in the strip.
 *
 * @param props The trigger's props.
 */
export function TabsTrigger(props) {
  return createElement(TabsPrimitive.Trigger, props);
}
