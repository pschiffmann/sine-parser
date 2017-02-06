import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'src/grammar.dart';
import 'src/lr.dart';

/// G = ({Z, E, T, F}, {a, +, *, (, )}, {Z → E, E → E + T, E → T, T → T * F,
///                                      T → F, F → ( E ), F → a}, Z)
final Grammar E = parse("""
  <Z> -> <E> ;
  <E> -> <E> '+' <T> ;
  <E> -> <T> ;
  <T> -> <T> '*' <F> ;
  <T> -> <F> ;
  <F> -> '(' <E> ')' ;
  <F> -> 'a' ;
""");

/// |states| == 46626
Grammar C = parse(new File("grammars/C.gardener").readAsStringSync());

void main() {
  var grammar = E;
  var watch = new Stopwatch()..start();
  var stateMachine = new StateMachine.fromGrammar(grammar);
  watch.stop();
  print("Built ${stateMachine.states.length} states from "
      "${grammar.nonterminals.length} nonterminals, "
      "${grammar.terminals.length} terminals and "
      "${grammar.productions.length} productions "
      "in ${watch.elapsedMilliseconds}ms");
  for (final state in stateMachine.states) {
    print("${state.id}:");
    state.closure.forEachKey((p, l) => print("$p: {${l.join(",")}}"));
    print("");
  }
}

/// Parses `source` as a Grammar definition. Because it splits at `/\s+/`, all
/// tokens must be separated by a whitespace!
Grammar parse(String source) {
  var tokens = source.trim().split(new RegExp(r'\s+'));
  var productions = <Production>[];
  var startSymbol;

  var name, definition;
  var it = tokens.iterator;
  while (it.moveNext()) {
    if (name == null) {
      name = new Nonterminal(it.current.substring(1, it.current.length - 1));
      definition = [];
      it.moveNext(); // skip over `->` token

      if (startSymbol == null) startSymbol = name;

      continue;
    }

    switch (it.current.substring(0, 1)) {
      case '<':
        definition.add(
            new Nonterminal(it.current.substring(1, it.current.length - 1)));
        break;
      case "'":
        definition
            .add(new Terminal(it.current.substring(1, it.current.length - 1)));
        break;
      case 'ε':
        definition.add(Terminal.emptyWord);
        break;
      case ';':
        productions.add(
            new Production(name, new BuiltList<GrammarSymbol>(definition)));
        name = definition = null;
        break;
      default:
        throw new ArgumentError("Can't parse token `${it.current}`");
    }
  }

  return new Grammar.fromProductions(productions, startSymbol);
}
