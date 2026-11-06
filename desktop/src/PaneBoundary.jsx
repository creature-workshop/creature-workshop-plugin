/**
 * @file The error boundary around the pane: when a component below it throws
 * while rendering, the pane shows the error's message in place of the tree
 * instead of Desktop losing the plugin. React provides a boundary only as a
 * class component.
 */
import { Component } from 'react';

/** The boundary. Renders its children until one of them throws, then the error's message. */
export class PaneBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  render() {
    if (this.state.error) {
      return <div className="workshop-error p-3 text-xs text-(--ui-text-tertiary)">{`pane error: ${this.state.error.message}`}</div>;
    }

    return this.props.children;
  }
}
