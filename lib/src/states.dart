///
library sine_parser.src.states;

import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'encode.dart';
import 'grammar.dart';

abstract class State {
  final Map<IntermediateState, GrammarSymbol> _predecessors = new HashMap();
  Map<IntermediateState, GrammarSymbol> get predecessors =>
      new UnmodifiableMapView(_predecessors);

  int get length;
  List<ActionPlaceholder> encode();
}

class IntermediateState extends State {
  final Map<Terminal, State> _lookAhead = new HashMap();
  final Map<Nonterminal, State> _continuations = new HashMap();

  final List<ActionPlaceholder> immediate = [];
  Map<Terminal, State> get lookAhead => new UnmodifiableMapView(_lookAhead);
  Map<Nonterminal, State> get continuations =>
      new UnmodifiableMapView(_continuations);
  final BuiltSet<Nonterminal> returnsAs;

  Iterable<Transition> get transitions sync* {
    for (final symbol in _lookAhead.keys) {
      yield new Transition<Terminal>._(this, symbol, _lookAhead);
    }
    for (final symbol in _continuations.keys) {
      yield new Transition<Nonterminal>._(this, symbol, _continuations);
    }
  }

  IntermediateState([Iterable<Nonterminal> returnsAs = const []])
      : returnsAs = new BuiltSet<Nonterminal>(returnsAs);

  Transition on(GrammarSymbol symbol) => symbol is Nonterminal
      ? new Transition<Nonterminal>._(this, symbol, _continuations)
      : new Transition<Terminal>._(this, symbol as Terminal, _lookAhead);

  int get length {
    var total = immediate.length;
    if (_lookAhead.length == 1 &&
        _lookAhead.values.first.predecessors.length == 1) {
      total += _lookAhead.values.first.length;
    } else if (_lookAhead.isNotEmpty) {
      total++;
    }
    if (_continuations.isNotEmpty) {
      total++;
    }
    return total;
  }

  List<ActionPlaceholder> encode() {
    final result = new List.from(immediate);
    if (_continuations.isNotEmpty) {
      final continueAction = _continuations.values.toSet().length == 1
          ? new ExpandPlaceholder(_continuations.values.first)
          : new ContinuePlaceholder(
              new BuiltMap<Nonterminal, State>(_continuations));
      result.add(new MarkPlaceholder(continueAction));
    }
    if (_lookAhead.length == 1 &&
        _lookAhead.values.first.predecessors.length == 1) {
      result.addAll(_lookAhead.values.first.encode());
    } else if (_lookAhead.isNotEmpty) {
      final lookAheadAction = _lookAhead.values.toSet().length == 1
          ? new ExpandPlaceholder(_lookAhead.values.first)
          : new LookAheadPlaceholder(new BuiltMap<Terminal, State>(_lookAhead));
      result.add(lookAheadAction);
    }
    return result;
  }
}

class Handle extends State {
  final Production production;

  Handle(this.production);

  int get length => 1;
  List<ActionPlaceholder> encode() => [new ReducePlaceholder(production)];
}

class Transition<S extends GrammarSymbol> {
  final Map<S, State> _successorMap;

  final IntermediateState from;
  final S via;

  State get to => _successorMap[via];

  void set to(State to) {
    final oldTo = _successorMap[via];
    if (oldTo != null) {
      oldTo._predecessors.remove(from);
    }

    if (to == null) {
      _successorMap.remove(via);
    } else {
      _successorMap[via] = to;
      to._predecessors[from] = via;
    }
  }

  Transition._(this.from, this.via, this._successorMap);
}
