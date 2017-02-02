import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'package:quiver_hashcode/hashcode.dart';
import 'package:tuple/tuple.dart' show Tuple2;
import 'grammar.dart';

class StateMachine {
  final Set<State> states = new HashSet<State>(
      equals: (s1, s2) => s1.closure == s2.closure,
      hashCode: (s) => s.closure.hashCode);

  Expando<int> stateNumbers = new Expando<int>();

  final State start;

  StateMachine(this.start);

  factory StateMachine.fromGrammar(Grammar grammar) {
    var firstState = new State.fromKernel(
        grammar.productions[grammar.startSymbol].map((production) =>
            new Tuple2(new Pass(production), Terminal.endOfInput)),
        grammar);

    var stateMachine = new StateMachine(firstState);
    var queue = new Queue<State>()..add(firstState);
    while (queue.isNotEmpty) {
      var state = queue.removeFirst();
      for (var pass in state.closure.keys) {
        if (pass.complete) continue;

        State followUp = state.advance(pass.expected, grammar);
        if (stateMachine.states.contains(followUp)) {
          followUp = stateMachine.states.lookup(followUp);
        } else {
          stateMachine.states.add(followUp);
          queue.add(followUp);
        }

        var transition = pass.expected is Terminal
            ? state.shiftTransitions
            : state.reduceTransitions;
        assert(!transition.containsKey(pass.expected));
        transition[pass.expected] = followUp;
      }
    }

    return stateMachine;
  }

  State lookup(State state) {
    var duplicate = states.lookup(state);
    if (duplicate == null) {
      stateNumbers[state] = states.length;
      states.add(state);
      return state;
    }
    return duplicate;
  }
}

class State {
  final BuiltSetMultimap<Pass, Terminal> closure;

  final Map<Terminal, State> shiftTransitions = new HashMap<Terminal, State>();
  final Map<Nonterminal, State> reduceTransitions =
      new HashMap<Nonterminal, State>();
  final Map<Terminal, Production> handles = new HashMap<Terminal, Production>();

  State(this.closure);

  factory State.fromKernel(
      Iterable<Tuple2<Pass, Terminal>> kernel, Grammar grammar) {
    var closure = kernel.toSet();
    var queue = new Queue<Tuple2<Pass, Terminal>>.from(closure);
    while (queue.isNotEmpty) {
      var current = queue.removeFirst();
      if (current.item1.complete || current.item1.expected is! Nonterminal)
        continue;

      var lookAhead = new Set()
        ..add(current.item2)
        ..addAll(current.item1.lookAhead(grammar));
      for (var production in grammar.productions[current.item1.expected]) {
        for (var terminal in lookAhead) {
          var pass = new Tuple2(new Pass(production), terminal);
          if (closure.add(pass)) queue.add(pass);
        }
      }
    }

    return new State(new BuiltSetMultimap<Pass, Terminal>.build((b) =>
        b.addIterable(closure,
            key: (tuple) => tuple.item1, value: (tuple) => tuple.item2)));
  }

  State advance(GrammarSymbol exit, Grammar grammar) {
    var kernel = [];
    closure.forEachKey((pass, lookAhead) {
      if (!pass.complete && pass.expected == exit) {
        for (var terminal in lookAhead) {
          kernel.add(new Tuple2(pass.next(), terminal));
        }
      }
    });
    return new State.fromKernel(kernel, grammar);
  }
}

class Pass {
  final Production production;
  final int progress;

  bool get complete => production.rhs.length == progress;

  GrammarSymbol get expected =>
      complete ? throw new StateError("done!") : production.rhs[progress];

  Pass(this.production, [this.progress = 0]) {
    if (progress > production.rhs.length)
      throw new StateError("$progress exceeds $production");
  }

  Pass next() => new Pass(production, progress + 1);

  /// Returns the look-ahead set for the [expected] nonterminal. It contains all
  /// [Terminal]s that can immediately follow [expected] in this production. May
  /// contain the same terminal twice.
  Iterable<Terminal> lookAhead(Grammar grammar) sync* {
    if (expected is! Nonterminal)
      throw new StateError("Only Nonterminals have a look-ahead set");
    for (var symbol in production.rhs.skip(progress + 1)) {
      if (symbol is Terminal) {
        yield symbol;
        break;
      }
      yield* grammar.first[symbol as Nonterminal].where((s) => s is Terminal);
      if (!grammar.nullable[symbol as Nonterminal]) break;
    }
  }

  String toString() => '${production.lhs} -> '
      '${production.rhs.getRange(0, progress).join(" ")}·'
      '${production.rhs.getRange(progress, production.rhs.length).join(" ")}';

  int get hashCode => hash2(production, progress);

  bool operator ==(other) =>
      other is Pass &&
      other.production == production &&
      other.progress == progress;
}
