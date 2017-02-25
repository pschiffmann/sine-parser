import 'dart:collection';
import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'src/encode.dart';
import 'src/grammar.dart';
import 'src/lr.dart';
import 'src/parser.dart';
import 'src/states.dart';

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

final Grammar C = parse(new File("grammars/C.gardener").readAsStringSync());
final inputForC = "INT IDENTIFIER ( INT IDENTIFIER , CHAR * IDENTIFIER [ ] ) "
    "{ RETURN IDENTIFIER * ( CONSTANT + CONSTANT ) ; }"
    .split(" ")
    .map((s) => new Terminal(s))
    .toList()..add(Terminal.endOfInput);

void main() {
  final grammar = E;
  final input = inputForE;
  final watch = new Stopwatch()..start();
  final firstState = generate(grammar);
  final actions = encode(firstState);
  watch.stop();

  print("Input grammar contains ${grammar.nonterminals.length} nonterminals, "
      "${grammar.terminals.length} terminals and "
      "${grammar.productions.values.length} productions.");
  countStates(
      firstState, grammar.terminals.length + grammar.nonterminals.length);
  countActions(actions, grammar.terminals.length, grammar.nonterminals.length);
  print("Generating LR graph, optimizing and encoding took ${watch.elapsed}");

  //printActions(actions);
  print("Parsed input $input into:");
  printAst(new Parser(actions).parse(input));
}

void countStates(IntermediateState firstState, int columnCount) {
  final discovered = new Set<State>();
  final queue = new Queue<IntermediateState>()..add(firstState);

  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    state.lookAhead.forEach((_, successor) {
      if (successor is IntermediateState && discovered.add(successor))
        queue.add(successor);
    });
    state.continuations.forEach((_, successor) {
      if (discovered.add(successor)) queue.add(successor);
    });
  }
  print('Canonical LR state graph contains ${discovered.length} states, '
      'resulting in a parser table with '
      '${discovered.length * columnCount} cells');
}

void countActions(BuiltList<BuiltList<ParserAction>> actions, int terminals,
    int nonterminals) {
  var listActions = 0, lookAheadRows = 0, continueRows = 0;
  for (final list in actions) {
    listActions += list.length;
    for (var action in list) {
      if (action is MarkAction) action = action.action;
      if (action is LookAheadAction) {
        lookAheadRows++;
      } else if (action is ContinueAction) {
        continueRows++;
      }
    }
  }
  print('sine parser algorithm uses a total of '
      '${listActions + lookAheadRows * terminals + continueRows * nonterminals}'
      ' cells ($listActions as action sequences, $lookAheadRows lookahead rows,'
      ' $continueRows continuation rows)');
}

void printActions(BuiltList<BuiltList<ParserAction>> actions) {
  var i = 0;
  for (var l in actions) print("${i++}: $l");
  print("");
}

void printAst(node, [String indent = '']) {
  final prefix =
      indent.isEmpty ? '' : '${indent.substring(0, indent.length - 3)} +-';
  if (node is AstNode) {
    print(prefix + node.type.toString());
    for (var i = 0; i < node.children.length; i++) {
      printAst(node.children[i],
          indent + (i == node.children.length - 1 ? '   ' : ' | '));
    }
  } else {
    print(prefix + node.toString());
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
