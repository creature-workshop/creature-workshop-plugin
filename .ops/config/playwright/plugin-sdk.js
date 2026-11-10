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
import { cloneElement, createElement } from 'react';
import { Select as Primitive, Switch as SwitchPrimitive, Tabs as TabsPrimitive, Tooltip as TooltipPrimitive } from 'radix-ui';
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

/**
 * Desktop's Button: a button, its variant and size dropped, or with
 * `asChild` its one child, such as a link, given the button's props.
 *
 * @param props The button's props.
 * @param props.variant Desktop's look for it; unused here.
 * @param props.size Desktop's size for it; unused here.
 * @param [props.asChild] Whether to draw the child in place of a button.
 */
export function Button({ variant, size, asChild = false, ...props }) {
  if (asChild) {
    return cloneElement(props.children, { 'data-variant': variant, 'data-size': size });
  }
  return createElement('button', { type: 'button', 'data-variant': variant, 'data-size': size, ...props });
}

/**
 * Desktop's Input: a text input, its size dropped.
 *
 * @param props The input's props.
 * @param props.size Desktop's size for it; unused here.
 */
export function Input({ size, ...props }) {
  return createElement('input', { 'data-size': size, ...props });
}

/**
 * Desktop's Textarea: a text area, its size dropped.
 *
 * @param props The text area's props.
 * @param props.size Desktop's size for it; unused here.
 */
export function Textarea({ size, ...props }) {
  return createElement('textarea', { 'data-size': size, ...props });
}

/**
 * Desktop's Codicon: an icon from VS Code's icon font, hidden from assistive technology.
 *
 * @param props The icon's props.
 * @param props.name The icon's name.
 */
export function Codicon({ name, ...props }) {
  return createElement('i', { 'aria-hidden': 'true', className: `codicon codicon-${name}`, ...props });
}


/**
 * Desktop's Switch: a radix switch with its thumb, its size dropped.
 *
 * @param props The switch's props.
 * @param props.size Desktop's size for it; unused here.
 */
export function Switch({ size, ...props }) {
  return createElement(SwitchPrimitive.Root, { 'data-size': size, ...props }, createElement(SwitchPrimitive.Thumb));
}

/**
 * Desktop's Tip: shows `label` in a tooltip while its one child is hovered
 * or focused, under a provider of its own, as Desktop's does outside the
 * app root; just the child when there is no label.
 *
 * @param props The tip's props.
 * @param props.label The tooltip's text.
 * @param props.children The element the tooltip belongs to.
 */
export function Tip({ label, children }) {
  if (!label) {
    return children;
  }
  const trigger = createElement(TooltipPrimitive.Trigger, { asChild: true }, children);
  const content = createElement(TooltipPrimitive.Portal, null, createElement(TooltipPrimitive.Content, null, label));
  return createElement(TooltipPrimitive.Provider, { delayDuration: 0 }, createElement(TooltipPrimitive.Root, null, trigger, content));
}
