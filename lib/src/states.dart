///
library sine_parser.src.states;

import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'package:quiver/collection.dart';
import 'package:quiver_hashcode/hashcode.dart';
import 'package:tuple/tuple.dart';
import 'grammar.dart';

/// Expands the assigned _kernel_ into the corresponding _closure_. The closure
/// is then grouped by the `expected` symbol of each pass.
Map<GrammarSymbol, Set<Pass>> _expand(BuiltSet<Pass> kernel, Grammar grammar) {
  final closure = new HashMap<GrammarSymbol, Set<Pass>>();
  final discovered = new HashSet<Pass>();
  final queue = new Queue<Pass>.from(kernel);

  void addTransition(Pass pass) {
    final bucket = closure.putIfAbsent(pass.expected, () => new HashSet());
    if (bucket.isNotEmpty && bucket.first.complete) {
      throw new Exception("S/R conflict of $pass and ${bucket.first}");
    }
    bucket.add(pass);
  }

  void addHandle(Pass pass) {
    final bucket = closure[pass.follow];
    if (bucket != null) {
      throw new Exception(
          (bucket.first.complete ? "R/R conflict" : "S/R conflict") +
              " of $pass and $bucket");
    } else {
      closure[pass.follow] = new HashSet<Pass>()..add(pass);
    }
  }

  /// May only be called for passes whose `expected` is a [Nonterminal]. Resolve
  /// the look-ahead set of `pass` for that nonterminal, and insert all new
  /// passes into `queue`.
  void discover(Pass pass) {
    final lookAhead = new HashSet<Terminal>();
    var nullable = true;
    for (var symbol in pass.production.rhs.skip(pass.progress + 1)) {
      if (symbol is Nonterminal) {
        for (final fst in grammar.first[symbol]) {
          if (fst is Terminal) lookAhead.add(fst);
        }
        nullable = grammar.nullable[symbol];
      } else {
        lookAhead.add(symbol as Terminal);
        nullable = false;
      }
      if (!nullable) break;
    }
    if (nullable) lookAhead.add(pass.follow);

    for (final production in grammar.productions[pass.expected]) {
      for (final symbol in lookAhead) {
        final successor = new Pass(production, symbol, 0);
        if (!discovered.contains(successor)) {
          discovered.add(successor);
          queue.add(successor);
        }
      }
    }
  }

  while (queue.isNotEmpty) {
    final pass = queue.removeFirst();
    if (pass.complete) {
      addHandle(pass);
    } else {
      addTransition(pass);
      if (pass.expected is Nonterminal) discover(pass);
    }
  }
  return closure;
}

///
StateGraph generate(Grammar grammar) {
  // Contains all [State]s that have been discovered but not yet processed.
  // For these states, transitions still need to be calculated.
  final queue = new Queue<Tuple2<BuiltSet<Pass>, State>>();

  // Maps kernels to states.
  final Map<BuiltSet<Pass>, State> states = {};

  final graph = new StateGraph();

  // Returns the [State] that corresponds to the assigned kernel. If the state
  // needed to be created, also insert it into `queue`.
  State lookup(Iterable<Pass> kernel, [Terminal shift]) {
    final builtKernel = new BuiltSet<Pass>(kernel);
    return states.putIfAbsent(builtKernel, () {
      final state = new State(shift);
      graph.add(state);
      queue.add(new Tuple2(builtKernel, state));
      return state;
    });
  }

  // Place the first state in `queue`.
  lookup(grammar.productions[grammar.startSymbol]
      .map((production) => new Pass(production, Terminal.endOfInput)));

  while (queue.isNotEmpty) {
    final closure = _expand(queue.first.item1, grammar);
    final state = queue.first.item2;
    queue.removeFirst();

    closure.forEach((symbol, passes) {
      if (passes.first.complete) {
        graph.addHandle(state, passes.first.production, symbol);
      } else {
        final successor = lookup(passes.map((pass) => pass.advance()),
            symbol is Terminal ? symbol : null);
        graph.connect(state, successor);
      }
    });
  }

  return graph;
}

class Pass {
  final Production production;
  final int progress;
  final Terminal follow;

  bool get complete => production.rhs.length == progress;

  GrammarSymbol get expected =>
      complete ? throw new StateError("done!") : production.rhs[progress];

  Pass(this.production, this.follow, [this.progress = 0]) {
    if (progress > production.rhs.length)
      throw new StateError("$progress exceeds $production");
  }

  Pass advance() => new Pass(production, follow, progress + 1);

  String toString() => '${production.lhs} -> '
      '${production.rhs.getRange(0, progress).join(" ")}·'
      '${production.rhs.getRange(progress, production.rhs.length).join(" ")} / '
      '$follow';

  int get hashCode => hash3(production, follow, progress);

  bool operator ==(other) =>
      other is Pass &&
      other.production == production &&
      other.follow == follow &&
      other.progress == progress;
}

class StateGraph {
  Set<Tuple2<State, State>> transitions = new HashSet();
  Map<State, Map<Terminal, Production>> handles = {};
  SetMultimap<State, State> predecessors;
  SetMultimap<State, State> successors;
  Map<State, int> states = new HashMap();

  void add(State state) {
    if (states.containsKey(state))
      throw new ArgumentError("Already in this graph");
    states[state] = states.length;
  }

  void connect(State from, State to) {
    assert(states.containsKey(from));
    assert(states.containsKey(to));
    transitions.add(new Tuple2(from, to));
  }

  void disconnect(State from, State to) {
    assert(states.containsKey(from));
    assert(states.containsKey(to));
    transitions.remove(new Tuple2(from, to));
  }

  void addHandle(State state, Production handle, Terminal lookAhead) {
    assert(states.containsKey(state));
    handles.putIfAbsent(state, () => new HashMap())[lookAhead] = handle;
  }
}

class State {
  final List<Terminal> shifts = [];

  State([Terminal terminal]) {
    if (terminal != null) shifts.add(terminal);
  }
}
