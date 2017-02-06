library sine_parser.src.grammar;

import 'dart:collection';
import 'package:built_collection/built_collection.dart';
import 'package:tuple/tuple.dart' show Tuple2;
import 'subset.dart';

/// Type union over [Nonterminal] and [Terminal].
abstract class GrammarSymbol {}

///
class Terminal implements GrammarSymbol {
  static final Map<String, Terminal> _cache = new HashMap<String, Terminal>();

  static const Terminal emptyWord = const _MetaTerminal('ε');
  static const Terminal endOfInput = const _MetaTerminal('\$');
  static const Terminal lexingError = const _MetaTerminal('↯');

  final String _name;

  factory Terminal(String name) =>
      _cache.putIfAbsent(name, () => new Terminal._(name));

  const Terminal._(this._name);

  String toString() => "'${_name.replaceAll("'", "\\'")}'";
}

///
class _MetaTerminal extends Terminal {
  const _MetaTerminal(String name) : super._(name);

  String toString() => '$_name';
}

///
class Nonterminal implements GrammarSymbol {
  static final Map<String, Nonterminal> _cache =
      new HashMap<String, Nonterminal>();

  final String _name;

  factory Nonterminal(String name) =>
      _cache.putIfAbsent(name, () => new Nonterminal._(name));

  const Nonterminal._(this._name);

  String toString() => '<$_name>';
}

///
class Production {
  final Nonterminal lhs;
  final BuiltList<GrammarSymbol> rhs;

  Production(this.lhs, this.rhs);

  String toString() => '$lhs -> ${rhs.join(" ")}';

  int get hashCode => lhs.hashCode ^ rhs.hashCode;
  bool operator ==(other) =>
      other is Production && other.lhs == lhs && other.rhs == rhs;
}

///
class Grammar {
  final String name;

  final BuiltSet<Nonterminal> nonterminals;
  final BuiltSet<Terminal> terminals;
  final BuiltMap<Nonterminal, BuiltSet<Production>> productions;
  final Nonterminal startSymbol;

  final BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>> first;
  final BuiltMap<Nonterminal, bool> nullable;

  final Superset<Terminal> _terminalSuperset;
  final Superset<Nonterminal> _nonterminalSuperset;
  final Superset<GrammarSymbol> _symbolSuperset;

  factory Grammar.fromProductions(
      Iterable<Production> productions, Nonterminal startSymbol,
      {String name}) {
    var productionMap = new BuiltMap<Nonterminal, BuiltSet<Production>>(() {
      var result = {};
      for (var production in productions) {
        result.putIfAbsent(production.lhs, () => []).add(production);
      }
      for (var nonterminal in result.keys) {
        result[nonterminal] = new BuiltSet<Production>(result[nonterminal]);
      }
      return result;
    }());
    var nonterminals = new BuiltSet<Nonterminal>(productionMap.keys),
        terminals = new BuiltSet<Terminal>.build((b) => b
          ..add(Terminal.endOfInput)
          ..addAll(productions
              .expand((p) => p.rhs)
              .where((symbol) => symbol is Terminal))),
        firstAndNullable = _calculateFirst(productionMap);

    if (!nonterminals.contains(startSymbol))
      throw new ArgumentError("Productions don't contain the start symbol");

    return new Grammar._(name, nonterminals, terminals, productionMap,
        startSymbol, firstAndNullable.item1, firstAndNullable.item2);
  }

  Grammar._(this.name, this.nonterminals, this.terminals, this.productions,
      this.startSymbol, this.first, this.nullable)
      : _nonterminalSuperset = new Superset<Nonterminal>(nonterminals),
        _terminalSuperset = new Superset<Terminal>(terminals),
        _symbolSuperset = new Superset<GrammarSymbol>(terminals);

  Subset<Terminal> terminalSet() => new Subset<Terminal>(_terminalSuperset);

  Subset<Nonterminal> nonterminalSet() =>
      new Subset<Nonterminal>(_nonterminalSuperset);

  Subset<GrammarSymbol> symbolSet() => new Subset(_symbolSuperset);

  String toString() =>
      (name != null ? '$name = ' : '') +
      '($nonterminals, $terminals, '
      '{${productions.values.expand((l) => l).join(", ")}}, $startSymbol)';
}

///
Tuple2<BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>>,
        BuiltMap<Nonterminal, bool>>
    _calculateFirst(BuiltMap<Nonterminal, BuiltSet<Production>> productions) {
  var first =
          new HashMap.fromIterable(productions.keys, value: (_) => new Set()),
      nullable =
          new HashMap.fromIterable(productions.keys, value: (_) => false),

      // All [Production]s in the list are computed _so far_, and will only
      // change their first sets if the key [Nonterminal] updates its own first
      // set, or becomes nullable.
      awaiting = new HashMap<Nonterminal, List<Production>>.fromIterable(
          productions.keys,
          value: (_) => []);

  var queue =
      new LinkedHashSet<Production>.from(productions.values.expand((x) => x));
  while (queue.isNotEmpty) {
    var production = queue.first;
    queue.remove(production);
    var current = first[production.lhs];
    var lengthBefore = current.length;

    var optional = production.rhs.isEmpty;
    for (var symbol in production.rhs) {
      current.add(symbol);
      if (symbol is Nonterminal) {
        current.addAll(first[symbol]);
        if (!nullable[symbol]) {
          optional = false;
          awaiting[symbol].add(production);
        }
      }
      if (!optional) break;
    }
    if (optional) {
      nullable[production.lhs] = true;
    }
    if (current.length != lengthBefore) {
      queue.addAll(awaiting[production.lhs]);
      awaiting[production.lhs].clear();
    }
  }

  for (var nonterminal in first.keys) {
    first[nonterminal] = new BuiltSet<GrammarSymbol>(first[nonterminal]);
  }
  return new Tuple2(new BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>>(first),
      new BuiltMap<Nonterminal, bool>(nullable));
}
