import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'grammar.dart' show Nonterminal, Terminal, Production;
import 'parser.dart';
import 'states.dart' show StateGraph, Transition;

typedef int addressOf(ActionSequence sequence);

abstract class ActionSequence {
  int get length;
  List<ActionPlaceholder> encode();
}

List<List<ParserAction>> encode(StateGraph graph) {
  final queue = new Queue<ActionSequence>();
  // queue.add(graph.states.first)
  final Map<ActionSequence, int> addresses = new HashMap();

  final result = <List<ParserAction>>[];

  int addressOf(ActionSequence sequence) {
    return addresses.putIfAbsent(sequence, () {
      queue.add(sequence);
      return result.length++;
    });
  }

  while (queue.isNotEmpty) {
    final sequence = queue.removeFirst();
    result[addressOf(sequence)] =
        sequence.encode().map((placeholder) => placeholder.resolve(addressOf));
  }

  return result;
}

abstract class ActionPlaceholder {
  ParserAction resolve(addressOf addressOf);
}

class ShiftPlaceholder extends ActionPlaceholder {
  final Terminal terminal;
  ShiftPlaceholder(this.terminal);

  ShiftAction resolve(addressOf _) => new ShiftAction(terminal);
}

class ExpandPlaceholder extends ActionPlaceholder {
  final ActionSequence target;
  ExpandPlaceholder(this.target);

  ExpandAction resolve(addressOf addressOf) {
    return new ExpandAction(addressOf(target));
  }
}

class LookAheadPlaceholder extends ActionPlaceholder {
  final BuiltMap<Terminal, Transition> branches;
  LookAheadPlaceholder(this.branches);

  LookAheadAction resolve(addressOf addressOf) =>
      new LookAheadAction(new BuiltMap<Terminal, ParserAction>(
          (b) => b.addIterable(branches.keys, value: (symbol) {
                final transition = branches[symbol];
                return transition.length == 1
                    ? transition.encode().first
                    : new ExpandAction(addressOf(transition));
              })));
}

class ContinuePlaceholder extends ActionPlaceholder {
  final BuiltMap<Nonterminal, Transition> branches;
  ContinuePlaceholder(this.branches);

  ContinueAction resolve(addressOf addressOf) =>
      new ContinueAction(new BuiltMap<Nonterminal, ParserAction>(
          (b) => b.addIterable(branches.keys, value: (symbol) {
                final transition = branches[symbol];
                return transition.length == 1
                    ? transition.encode().first
                    : new ExpandAction(addressOf(transition));
              })));
}

class ReducePlaceholder extends ActionPlaceholder {
  final Production production;
  ReducePlaceholder(this.production);

  ReduceAction resolve(addressOf _) => new ReduceAction(production);
}

class MarkPlaceholder extends ActionPlaceholder {
  final ActionPlaceholder action;
  MarkPlaceholder(this.action);

  MarkAction resolve(addressOf addressOf) =>
      new MarkAction(action.resolve(addressOf));
}
