import 'package:built_collection/built_collection.dart';
import 'grammar.dart';
import 'lr.dart';
import 'parser.dart';

BuiltList<BuiltList<ParserAction>> encode(final StateMachine stateMachine) {
  final Expando<List<ParserAction>> actions = new Expando();
  final List<List<ParserAction>> heap = [];
  for (final state in stateMachine.states) {
    final immediate = _buildImmediate(state, heap, stateMachine.states.length);
    final continuation = _buildContinuation(state);
    actions[state] = continuation == null
        ? [immediate]
        : [new MarkAction(continuation), immediate];
  }
  return new BuiltList<BuiltList<ParserAction>>.build((ListBuilder b) => b
    ..addAll(stateMachine.states
        .map((state) => new BuiltList<ParserAction>(actions[state])))
    ..addAll(heap.map((actions) => new BuiltList<ParserAction>(actions))));
}

ParserAction _buildImmediate(
    State state, List<List<ParserAction>> heap, int offset) {
  final builder = new MapBuilder<Terminal, ParserAction>();
  state.shiftTransitions.forEach((terminal, nextState) {
    builder[terminal] = new ExpandAction(offset + heap.length);
    heap.add([new ShiftAction(terminal), new ExpandAction(nextState.id)]);
  });
  state.handles.forEach((terminal, production) {
    builder[terminal] = new ReduceAction(production);
  });
  var lookAhead = builder.build();
  if (lookAhead.length <= 1) {
    return lookAhead.values.first;
  }
  return new LookAheadAction(lookAhead);
}

ParserAction _buildContinuation(State state) {
  final transitions = state.gotoTransitions;
  switch (transitions.length) {
    case 0:
      return null;
    case 1:
      return new ExpandAction(transitions.values.first.id);
    default:
      return new ContinueAction(new BuiltMap<Nonterminal, ParserAction>.build(
          (b) => b.addIterable(transitions.keys,
              value: (Nonterminal n) => new ExpandAction(transitions[n].id))));
  }
}
