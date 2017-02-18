import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'src/grammar.dart';
import 'src/lr.dart';
import 'src/parser.dart';

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
final inputForE = "a+a*(a*a)".split("").map((s) => new Terminal(s)).toList()
  ..add(Terminal.endOfInput);

/// |states| == 46626
final Grammar C = parse(new File("grammars/C.gardener").readAsStringSync());
final inputForC = "INT IDENTIFIER ( INT IDENTIFIER , CHAR * IDENTIFIER [ ] ) "
    "{ RETURN IDENTIFIER * ( CONSTANT + CONSTANT ) ; }"
    .split(" ")
    .map((s) => new Terminal(s))
    .toList()..add(Terminal.endOfInput);

void main() {
  final grammar = E;
  //final input = inputForE;
  final watch = new Stopwatch()..start();
  final graph = generate(grammar);
  watch.stop();

  print("Built ${graph.length} "
      "states from ${grammar.nonterminals.length} nonterminals, "
      "${grammar.terminals.length} terminals and "
      "${grammar.productions.values.expand((x) => x).length} productions "
      "in ${watch.elapsed}");

  //analyze(grammar, stateMachine);
  //printStates(stateMachine);
  //printActions(parser);

  //print("Parsed input $input into:");
  //printAst(parser.parse(input));
}

void printActions(Parser parser) {
  var i = 0;
  for (var l in parser.actions) print("${i++}: $l");
  print("");
}

void printAst(node, [String indent = '']) {
  if (node is AstNode) {
    print(indent + '-' + node.type.toString());
    for (var child in node.children) {
      printAst(child, indent + ' |');
    }
  } else {
    print(indent + '-' + node.toString());
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
