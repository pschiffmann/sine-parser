/// optimizations are executed in the following order:
///
///  1. merge correlating states; two states correlate if they have identical
///     lookahead transitions, identical continuations, handles that reduce the
///     same productions, and the lookahead actions can be merged without
///     conflict.
///  2. inline trivial states; a state is trivial, if it has only a single
///     predecessor.
import 'states.dart';

void optimize(StateGraph graph) {
  _mergeEquivalent(graph);
  _inlineSinglyReferenced(graph);
}

/// Sorts all states into a hash table by transitions and handles.
void _mergeEquivalent(StateGraph graph) {
/*
  table = {}
  queue = graph.states
  for state in queue:
    candidates = table[hash(state.lookAheadTransitions \ handles, state.continuations)]
    for candidate in candidates:
      if state.handles fits into candidate.lookAheadTransitions:
        add state.handles to candidate
        for predecessor in predecessors(state):
          redirect transition (predecessor, state) to (predecessor, candidate)
          queue.append(predecessor)
    else:
      candidates.append(state)
*/
}

void _inlineSinglyReferenced(StateGraph graph) {
/*
  for transition in graph.transitions:
    if transition.target.predecessors == 1:
      transition.actions.append(transition.target.encode())
      graph.remove(transition.target)
      transition.target = null
*/
}
