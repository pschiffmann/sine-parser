import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'package:quiver_hashcode/hashcode.dart';
import 'package:tuple/tuple.dart' show Tuple2;
import 'grammar.dart';

class StateMachine {
  final BuiltList<State> states;

  final Grammar grammar;

  State get start => states.first;

  StateMachine(this.states, this.grammar);

  factory StateMachine.fromGrammar(Grammar grammar) {
    // Contains all [State]s that have been discovered but not yet processed.
    // For these states, transitions still need to be calculated.
    final queue = new Queue<State>();

    // Maps kernels to states.
    final Map<BuiltSetMultimap<Pass, Terminal>, State> states = {};

    // Returns the [State] that corresponds to the assigned kernel. If the state
    // needed to be created, also insert it into `queue`.
    final forKernel = (BuiltSetMultimap<Pass, Terminal> kernel) =>
        states.putIfAbsent(kernel, () {
          final state = new State.fromKernel(states.length, kernel, grammar);
          queue.add(state);
          return state;
        });

    // Initialize `queue` with the first state.
    forKernel(new BuiltSetMultimap<Pass, Terminal>.build((b) => b.addIterable(
        grammar.productions[grammar.startSymbol],
        key: (Production p) => new Pass(p),
        value: (Production p) => Terminal.endOfInput)));

    while (queue.isNotEmpty) {
      final state = queue.removeFirst();
      for (final pass in state.closure.keys) {
        if (pass.complete) continue;

        final followUp = forKernel(state.advance(pass.expected));

        var transition = pass.expected is Terminal
            ? state.shiftTransitions
            : state.reduceTransitions;
        assert(!transition.containsKey(pass.expected));
        transition[pass.expected] = followUp;
      }
    }

    return new StateMachine(new BuiltList<State>(states.values), grammar);
  }
}

class State {
  final int id;
  final BuiltSetMultimap<Pass, Terminal> closure;

  final Map<Terminal, State> shiftTransitions = new HashMap<Terminal, State>();
  final Map<Nonterminal, State> reduceTransitions =
      new HashMap<Nonterminal, State>();
  final Map<Terminal, Production> handles = new HashMap<Terminal, Production>();

  State(this.id, this.closure);

  factory State.fromKernel(
      int id, BuiltSetMultimap<Pass, Terminal> kernel, Grammar grammar) {
    final closure = new HashSet<Tuple2<Pass, Terminal>>();
    kernel.forEachKey((pass, lookAhead) {
      for (final terminal in lookAhead) {
        closure.add(new Tuple2(pass, terminal));
      }
    });

    final queue = new Queue<Tuple2<Pass, Terminal>>.from(closure);
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

    return new State(
        id,
        new BuiltSetMultimap<Pass, Terminal>.build((b) => b.addIterable(closure,
            key: (tuple) => tuple.item1, value: (tuple) => tuple.item2)));
  }

  BuiltSetMultimap<Pass, Terminal> advance(GrammarSymbol exit) {
    var kernel = new SetMultimapBuilder<Pass, Terminal>();
    closure.forEachKey((pass, lookAhead) {
      if (!pass.complete && pass.expected == exit) {
        kernel.addValues(pass.next(), lookAhead);
      }
    });
    return kernel.build();
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
