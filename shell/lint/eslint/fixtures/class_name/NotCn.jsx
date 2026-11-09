/**
 * @file A fixture for house/class-name that fails twice: a className given as
 * a plain string, and one given as an expression that is not a cn call.
 */

/** A row whose class list is a plain string. */
export function Plain() {
  return (
    <div className="row flex" />
  );
}

/** A row whose class list is joined by hand. */
export function Joined() {
  const classes = ['row', 'flex'];
  return (
    <div
      className={classes.join(' ')}
    />
  );
}
