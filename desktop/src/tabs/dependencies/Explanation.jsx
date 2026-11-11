/**
 * @file Why the project has one dependency, under its row: the model's
 * explanation, or that it is being asked, or that it could not say.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { DetailsToggle } from '../../failures/DetailsToggle.jsx';
import { LoadingDots } from '../../pane/body/LoadingDots.jsx';

/** The mark on an explanation, as on the setup form's suggested fields. */
const MODEL_HINT = 'Model suggestion';

/**
 * What the mark under an explanation says: that a model suggested it, and
 * which model, so an answer from another model than the one chosen is
 * never silent.
 *
 *     hintOf('stepfun/step-3.7-flash:free')  ->  'Model suggestion, from stepfun/step-3.7-flash:free'
 *
 * @param {string} [model] The model that answered, or empty when it is not known.
 *
 * @returns {string} The mark.
 */
export function hintOf(model) {
  return model ? `${MODEL_HINT}, from ${model}` : MODEL_HINT;
}

/**
 * "Asking the model" with dots while the question is out; the explanation
 * with "Model suggestion, from <model>" under it once it arrives; and "I couldn't get an
 * explanation of <tool>." with Try again when none came back, and Show
 * details, which reveals why: what the provider said, or the failed
 * request's code, status and message.
 *
 * @param props The component's props.
 * @param {string} props.tool The tool's name.
 * @param {{phase: string, text?: string, model?: string, details?: string}} props.explanation The question's state, as useExplanation returns it.
 * @param {() => void} props.onRetry Asks again.
 */
export function Explanation({ tool, explanation, onRetry }) {
  if (explanation.phase === 'asking') {
    return <span className={cn('workshop-explanation-asking', 'text-(--ui-text-tertiary)')}><LoadingDots>Asking the model</LoadingDots></span>;
  }
  if (explanation.phase === 'failed') {
    return (
      <span role="alert" className={cn('workshop-explanation-failed', 'flex', 'flex-wrap', 'items-center', 'gap-2', 'text-(--ui-text-secondary)')}>
        {`I couldn't get an explanation of ${tool}.`}
        <Button size="xs" variant="outline" onClick={onRetry}>Try again</Button>
        <DetailsToggle details={explanation.details} />
      </span>
    );
  }

  return (
    <span className={cn('workshop-explanation', 'flex', 'flex-col', 'gap-1')}>
      <span className={cn('workshop-explanation-text', 'text-(--ui-text-secondary)')}>{explanation.text}</span>
      <span className={cn('workshop-explanation-hint', 'text-[0.6875rem]', 'text-(--ui-text-tertiary)')}>{hintOf(explanation.model)}</span>
    </span>
  );
}
