import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'grammar.dart' show Nonterminal, Terminal, Production;
import 'parser.dart';
import 'states.dart';

typedef int addressOf(State sequence);

BuiltList<BuiltList<ParserAction>> encode(State firstState) {
  final queue = new Queue<State>()..add(firstState);
  final Map<State, int> addresses = new HashMap();

  final result = <BuiltList<ParserAction>>[];

  int addressOf(State state) {
    return addresses.putIfAbsent(state, () {
      queue.add(state);
      return result.length++;
    });
  }

  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    result[addressOf(state)] = new BuiltList<ParserAction>(
        state.encode().map((placeholder) => placeholder.resolve(addressOf)));
  }

  return new BuiltList<BuiltList<ParserAction>>(result);
}

ParserAction unpackSingle(State state, addressOf addressOf) => state.length == 1
    ? state.encode().single.resolve(addressOf)
    : new ExpandAction(addressOf(state));

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

  ParserAction resolve(addressOf addressOf) => unpackSingle(target, addressOf);
}

class LookAheadPlaceholder extends ActionPlaceholder {
  final BuiltMap<Terminal, State> branches;
  LookAheadPlaceholder(this.branches);

  LookAheadAction resolve(addressOf addressOf) =>
      new LookAheadAction(new BuiltMap<Terminal, ParserAction>.build((b) =>
          b.addIterable(branches.keys,
              value: (symbol) => unpackSingle(branches[symbol], addressOf))));
}

class ContinuePlaceholder extends ActionPlaceholder {
  final BuiltMap<Nonterminal, State> branches;
  ContinuePlaceholder(this.branches);

  ContinueAction resolve(addressOf addressOf) =>
      new ContinueAction(new BuiltMap<Nonterminal, ParserAction>.build((b) =>
          b.addIterable(branches.keys,
              value: (symbol) => unpackSingle(branches[symbol], addressOf))));
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
