/** @file Boxes that say what they are, by class, by role, or by being a semantic element. */

/** A named list. */
export function Named({ items, open }) {
  return (
    <section className="flex">
      <div className="workshop-list p-2">
        {items.map((item) => <span key={item} className={`workshop-item ${open ? 'open' : ''}`}>{item}</span>)}
      </div>
      <span role="status">ready</span>
    </section>
  );
}
