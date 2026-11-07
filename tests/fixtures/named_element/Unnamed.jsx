/** @file Boxes that say nothing about what they are. */

/** An unnamed list. */
export function Unnamed({ items }) {
  return (
    <div>
      <div className="p-2 text-xs">
        {items.map((item) => <span key={item} className="font-medium">{item}</span>)}
      </div>
    </div>
  );
}
