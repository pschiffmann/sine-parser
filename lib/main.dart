import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'src/encode.dart';
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

/// |states| == 46626
Grammar C = parse(new File("grammars/C.gardener").readAsStringSync());

void main() {
  final grammar = E;
  final watch = new Stopwatch()..start();
  final stateMachine = new StateMachine.fromGrammar(grammar);
  watch.stop();

  print("Built ${stateMachine.states.length} states from "
      "${grammar.nonterminals.length} nonterminals, "
      "${grammar.terminals.length} terminals and "
      "${grammar.productions.values.expand((x) => x).length} productions "
      "in ${watch.elapsed}");
  analyze(grammar, stateMachine);
  // printStates(stateMachine);

  final parser = new Parser(encode(stateMachine));
  var i = 0;
  for (var l in parser.actions) print("${i++}: $l");
  print("");

  final input = "a+a*(a*a)".split("").map((s) => new Terminal(s)).toList()
    ..add(Terminal.endOfInput);
  print(parser.parse(input));
}

void analyze(Grammar grammar, StateMachine sm) {
  var filledCells = 0, trivialActionRows = 0, emptyGotoRows = 0;
  var totalCells = (grammar.nonterminals.length + grammar.terminals.length) *
      sm.states.length;
  for (final state in sm.states) {
    if (state.shiftTransitions.length + state.handles.length == 1)
      trivialActionRows++;
    if (state.gotoTransitions.isEmpty) emptyGotoRows++;
    filledCells += state.shiftTransitions.length +
        state.gotoTransitions.length +
        state.handles.length;
  }
  print("analyzing parser table:");
  print("  ${(100 * filledCells / totalCells).toStringAsPrecision(4)}% "
      "of the table is filled ($filledCells / $totalCells)");
  print("  ${emptyGotoRows} empty rows in the goto table");
  // print("  ${trivialActionRows} trivial rows in the action table");
}

void printStates(StateMachine sm) {
  for (final state in sm.states) {
    print("${state.id}:");
    print("shift: {" +
        state.shiftTransitions.keys
            .map((k) => "$k: ${state.shiftTransitions[k].id}")
            .join(", ") +
        "}");
    print("reduce: ${state.handles}");
    print("goto: {" +
        state.gotoTransitions.keys
            .map((k) => "$k: ${state.gotoTransitions[k].id}")
            .join(", ") +
        "}");
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
