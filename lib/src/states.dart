///
library sine_parser.src.states;

import 'dart:collection';
import 'package:quiver/collection.dart';
import 'package:tuple/tuple.dart';
import 'grammar.dart';

class StateGraph {
  Map<Tuple2<State, State>, Set<Nonterminal>> transitions = new HashMap();
  Map<State, List<Terminal>> shifts = new HashMap();
  Map<State, Map<Terminal, Production>> handles = new HashMap();
  Map<State, Map<Nonterminal, State>> continuations = new HashMap();
  SetMultimap<State, State> predecessors;
  int _states = 0;

  int get states => _states;

  State allocate() => new State._(_states++, this);

  void connect(State from, State to, Set<Nonterminal> nonterminals) {
    assert(from._graph == this);
    assert(to._graph == this);
    assert(!transitions.containsKey(new Tuple2(from, to)));
    transitions[new Tuple2(from, to)] = nonterminals;
  }

  void disconnect(State from, State to) {
    assert(from._graph == this);
    assert(to._graph == this);
    transitions.remove(new Tuple2(from, to));
  }

  void redirect(State from, State oldTarget, State newTarget) {}

  void addHandle(State state, Production handle, Terminal lookAhead) {
    assert(state._graph == this);
    handles.putIfAbsent(state, () => new HashMap())[lookAhead] = handle;
  }

  void addImmediateTransition(State from, State to, Terminal lookAhead) {}
  void addContinuation(State from, State to, Nonterminal nonterminal) {}
}

class State {
  final int id;
  final StateGraph _graph;
  State._(this.id, this._graph);

  bool operator ==(other) => other is State && other.id == id;
  int get hashCode => id.hashCode;
}
