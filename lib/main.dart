import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'src/grammar.dart';
import 'src/lr.dart';

/// G = ({Z, E, T, F}, {a, +, *, (, )}, {Z → E, E → E + T, E → T, T → T * F,
///                                      T → F, F → ( E ), F → a}, Z)
final Grammar grammar = parse("""
  <Z> -> <E> ;
  <E> -> <E> '+' <T> ;
  <E> -> <T> ;
  <T> -> <T> '*' <F> ;
  <T> -> <F> ;
  <F> -> '(' <E> ')' ;
  <F> -> 'a' ;
""");

Grammar C = parse(new File("grammars/C.gardener").readAsStringSync());

void main() {
  C.productions.forEach((n, p) {
    print("$n / ${C.first[n]}");
    print(p.join("\n"));
    print("");
  });
  generate(C);

  /*var input = ['a', '+', 'a', '*', 'a'].map((s) => new Terminal(s)).toList();
  print('Parsing input $input with grammar G = $grammar');

  for (var nonterminal in grammar.nonterminals) {
    print("fst($nonterminal) = ${grammar.first[nonterminal]}");
  }*/
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
