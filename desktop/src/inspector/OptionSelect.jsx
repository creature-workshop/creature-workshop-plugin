/**
 * @file The list a field picks one of its options from.
 */

import { cn, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@hermes/plugin-sdk';

/**
 * Desktop's select, labelled `label`, showing `value`, or `placeholder`
 * when `value` is empty, and listing `options`. Picking one calls `onPick`
 * with it.
 *
 * @param props The component's props.
 * @param {string} props.label The list's label, for assistive technology.
 * @param {string[]} props.options The options, in order.
 * @param {string} props.value The option shown, or empty.
 * @param {string} props.placeholder What shows while no option is.
 * @param {boolean} props.disabled Whether the list cannot be opened.
 * @param {(option: string) => void} props.onPick Takes the option picked.
 */
export function OptionSelect({ label, options, value, placeholder, disabled, onPick }) {
  return (
    <Select value={value} disabled={disabled} onValueChange={onPick}>
      <SelectTrigger aria-label={label} className={cn('workshop-option-select')}>
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        {options.map((option) => <SelectItem key={option} value={option}>{option}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}
