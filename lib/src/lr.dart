import 'package:built_collection/built_collection.dart';
import 'dart:collection';
import 'grammar.dart';

class Automata {}

class State {
  Set<Progress> closure = new HashSet<Progress>();

  Iterable<Terminal> get lookAheads sync* {
    for (var progress in closure) {
      if (!progress.done && progress.current is Terminal)
        yield progress.current;
    }
  }

  Iterable<Nonterminal> get continuations sync* {
    for (var progress in closure) {
      if (!progress.done && progress.current is Nonterminal)
        yield progress.current;
    }
  }

  Iterable<Progress> get completed sync* {
    for (var progress in closure) {
      if (progress.done) yield progress;
    }
  }
}

class Progress {
  final Production production;
  final BuiltSet<Terminal> lookAhead;
  final int offset;

  bool get done => production.rhs.length == offset;
  GrammarSymbol get current =>
      done ? throw new Exception("done!") : production.rhs[offset];

  Progress(this.production, this.lookAhead, this.offset);

  String toString() => '${production.lhs} -> '
      '${production.rhs.getRange(0, offset).join(" ")}·'
      '${production.rhs.getRange(offset, production.rhs.length).join(" ")} / '
      '$lookAhead';

  int get hashCode =>
      production.hashCode ^ lookAhead.hashCode ^ offset.hashCode;
  bool operator ==(other) =>
      other is Progress &&
      other.production == production &&
      other.lookAhead == lookAhead &&
      other.offset == offset;
}

Automata generate(Grammar grammar) {
  var state = new State();
  for (var production in grammar.productions[grammar.startSymbol]) {
    state.closure.add(new Progress(
        production, new BuiltSet<Terminal>([Terminal.endOfInput]), 0));
  }

  var queue = new ListQueue.from(state.continuations);
  while (queue.isNotEmpty) {
    var nonterminal = queue.removeFirst();
    for (var production in grammar.productions[nonterminal]) {
      var progress = new Progress(
          production, new BuiltSet<Terminal>([Terminal.endOfInput]), 0);
      if (!state.closure.contains(progress)) {
        queue.addAll(production.rhs.where((x) => x is Nonterminal));
        state.closure.add(progress);
      }
    }
  }

  print(state.closure.join("\n"));
  return null;
}
