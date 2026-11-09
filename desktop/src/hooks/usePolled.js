/**
 * @file Polling the backend from a component: the hook usePolled reads an
 * answer when the component mounts, again on an interval, and again at once
 * whenever what it reads changes, and hands back the latest answer.
 */

import { useEffect, useState } from 'react';

/**
 * The latest answer of a read that runs now and every `seconds` after,
 * starting over whenever `subject` changes; null until the first answer.
 * A read that answers after the component went away, or after the subject
 * changed, is dropped.
 *
 *   const status = usePolled(() => client.repoStatus(root), 20, root);
 *
 * @param read A function that asks for the answer and returns a promise of it.
 * @param seconds How long to wait between reads.
 * @param subject What the read is about; a new value starts the reads over.
 */
export function usePolled(read, seconds, subject) {
  const [answer, setAnswer] = useState(null);
  useEffect(poll(read, seconds, setAnswer), [subject, seconds]);
  return answer;
}

/**
 * The effect that reads at once and every `seconds` after, keeping each
 * answer, until the subject or the interval changes or the component goes away.
 *
 * @effect
 * @param read A function that asks for the answer and returns a promise of it.
 * @param seconds How long to wait between reads.
 * @param setAnswer The setter of the answer.
 */
function poll(read, seconds, setAnswer) {
  return () => {
    let open = true;
    const once = () => read().then((answer) => open && setAnswer(answer));
    once();
    const timer = setInterval(once, seconds * 1000);
    return () => {
      open = false;
      clearInterval(timer);
    };
  };
}
