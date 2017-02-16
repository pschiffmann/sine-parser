///
library sine_parser.src.states;

import 'encode.dart' show ActionSequence, ActionPlaceholder;
import 'grammar.dart';

class StateGraph {
  final Set<State> states = new Set();

  State allocate() {
    final state = new State._(states.length, this);
    states.add(state);
    return state;
  }
}

class State implements ActionSequence {
  final int id;
  final StateGraph _graph;
  State._(this.id, this._graph);

  final List<ActionPlaceholder> immediateActions = [];
  Set<Nonterminal> returnsAs;
  final Map<Terminal, Transition> lookAheadTransitions = {};
  final Map<Terminal, Production> handles = {};
  final Map<Nonterminal, Transition> continuations = {};

  encode() => throw new UnimplementedError();
  int get length => throw new UnimplementedError();
}

class Transition implements ActionSequence {
  State target;
  final List<ActionPlaceholder> actions;

/*  bool get isHandle =>
      target == null &&
      actions.length == 1 &&
      actions.first is ReducePlaceholder;*/

  Transition({this.target, List<ActionPlaceholder> actions})
      : actions = actions ?? [];

  encode() => throw new UnimplementedError();
  int get length => throw new UnimplementedError();
}
