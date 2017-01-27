library sine_parser.src.grammar;

import 'dart:collection';
import 'package:built_collection/built_collection.dart';

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
  final BuiltSet<Nonterminal> nonterminals;
  final BuiltSet<Terminal> terminals;
  final BuiltMap<Nonterminal, BuiltSet<Production>> productions;
  final Nonterminal startSymbol;

  final BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>> first;

  Grammar.fromProductions(Iterable<Production> productions, this.startSymbol)
      : nonterminals = new BuiltSet<Nonterminal>(productions.map((p) => p.lhs)),
        terminals = new BuiltSet<Terminal>(productions
            .expand((p) => p.rhs)
            .where((symbol) => symbol is Terminal)),
        productions = new BuiltMap<Nonterminal, BuiltSet<Production>>(() {
          var result = {};
          for (var production in productions) {
            result.putIfAbsent(production.lhs, () => []).add(production);
          }
          for (var nonterminal in result.keys) {
            result[nonterminal] = new BuiltSet<Production>(result[nonterminal]);
          }
          return result;
        }()),
        first = _calculateFirst(productions) {
    if (!nonterminals.contains(startSymbol))
      throw new ArgumentError("Productions don't contain the start symbol");
  }

  String toString() => '($nonterminals, $terminals, '
      '{${productions.values.expand((l) => l).join(", ")}}, $startSymbol)';
}

///
BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>> _calculateFirst(
    Iterable<Production> productions) {
  var first = new HashMap.fromIterable(productions,
      key: (p) => p.lhs, value: (_) => new Set());
  var awaiting = new HashMap<Nonterminal, List<Production>>.fromIterable(
      productions,
      key: (p) => p.lhs,
      value: (_) => []);

  var queue = new LinkedHashSet<Production>.from(productions);
  while (queue.isNotEmpty) {
    var production = queue.first;
    queue.remove(production);
    var current = first[production.lhs];
    var lengthBefore = current.length;

    var nullable = true;
    for (var symbol in production.rhs) {
      if (symbol is Terminal) {
        current.add(symbol);
        nullable = false;
      } else {
        current.addAll(first[symbol as Nonterminal]);
        if (!current.remove(Terminal.emptyWord)) {
          nullable = false;
          awaiting[symbol].add(production);
        }
      }
      if (!nullable) break;
    }
    if (nullable) {
      first[production.lhs].add(Terminal.emptyWord);
    }
    if (current.length != lengthBefore) {
      queue.addAll(awaiting[production.lhs]);
      awaiting[production.lhs].clear();
    }
  }

  for (var nonterminal in first.keys) {
    first[nonterminal] = new BuiltSet<GrammarSymbol>(first[nonterminal]);
  }
  return new BuiltMap<Nonterminal, BuiltSet<GrammarSymbol>>(first);
}
