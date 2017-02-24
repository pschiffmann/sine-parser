import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'grammar.dart' show Nonterminal, Terminal, Production;
import 'parser.dart';
import 'states.dart';

typedef int addressOf(State sequence);

List<List<ParserAction>> encode(State firstState) {
  final queue = new Queue<State>()..add(firstState);
  final Map<State, int> addresses = new HashMap();

  final result = <List<ParserAction>>[];

  int addressOf(State state) {
    return addresses.putIfAbsent(state, () {
      queue.add(state);
      return result.length++;
    });
  }

  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    result[addressOf(state)] = state
        .encode()
        .map((placeholder) => placeholder.resolve(addressOf))
        .toList();
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
  final State target;
  ExpandPlaceholder(this.target);

  ExpandAction resolve(addressOf addressOf) {
    return new ExpandAction(addressOf(target));
  }
}

class LookAheadPlaceholder extends ActionPlaceholder {
  final BuiltMap<Terminal, State> branches;
  LookAheadPlaceholder(this.branches);

  LookAheadAction resolve(addressOf addressOf) =>
      new LookAheadAction(new BuiltMap<Terminal, ParserAction>.build(
          (b) => b.addIterable(branches.keys, value: (symbol) {
                final successor = branches[symbol];
                return successor.length == 1
                    ? successor.encode().single.resolve(addressOf)
                    : new ExpandAction(addressOf(successor));
              })));
}

class ContinuePlaceholder extends ActionPlaceholder {
  final BuiltMap<Nonterminal, State> branches;
  ContinuePlaceholder(this.branches);

  ContinueAction resolve(addressOf addressOf) =>
      new ContinueAction(new BuiltMap<Nonterminal, ParserAction>.build(
          (b) => b.addIterable(branches.keys, value: (symbol) {
                final successor = branches[symbol];
                return successor.length == 1
                    ? successor.encode().single.resolve(addressOf)
                    : new ExpandAction(addressOf(successor));
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
