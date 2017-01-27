import 'package:built_collection/built_collection.dart';
import 'grammar.dart';

class Parser {
  /// Referenced by [ExpandAction]s.
  final BuiltMap<Nonterminal, BuiltList<ParserAction>> expansions;

  final ExpandAction startAction;

  Parser(this.expansions, this.startAction);

  Object parse(Iterable<Terminal> input) {
    var context = new ParsingContext(expansions, input.iterator);
    context.actions.add(startAction);

    while (context.actions.isNotEmpty) {
      context.actions.removeLast().execute(context);
    }

    if (context.reduced.length != 1)
      throw new Exception("action stack is empty, but reduced stack is not "
          "- that's a bug in the parser generator :(");
    if (context.tokens.current != null)
      throw new Exception("action stack is empty, but input is not exhausted "
          "- that's a bug in the parser generator :(");

    return context.reduced.first;
  }
}

class ParsingContext {
  final BuiltMap<Nonterminal, BuiltList<ParserAction>> expansions;

  Iterator<Terminal> tokens;
  List reduced = [];
  List<ParserAction> actions = [];

  ParsingContext(this.expansions, this.tokens);
}

abstract class ParserAction {
  void execute(ParsingContext context);
}

class ShiftAction extends ParserAction {
  final Terminal terminal;

  ShiftAction(this.terminal);

  void execute(ParsingContext context) {
    if (context.tokens.current != terminal)
      throw new Exception(
          "Input rejected at token `${context.tokens.current}`");
    context.reduced.add(context.tokens.current);
    context.tokens.moveNext();
  }
}

class ExpandAction extends ParserAction {
  final Nonterminal nonterminal;

  ExpandAction(this.nonterminal);

  void execute(ParsingContext context) {
    context.actions.addAll(context.expansions[nonterminal]);
  }
}

class BranchAction extends ParserAction {
  final Map<Terminal, List<ParserAction>> branches;

  BranchAction(this.branches);

  void execute(ParsingContext context) {
    if (branches.containsKey(context.tokens.current)) {
      context.actions.addAll(branches[context.tokens.current]);
    } else if (branches.containsKey(Terminal.emptyWord)) {
      context.actions.addAll(branches[Terminal.emptyWord]);
    }
  }
}

class ReturnAwareBranchAction extends ParserAction {
  void execute(ParsingContext context) {}
}

class ConstructAction extends ParserAction {
  final Production production;

  ConstructAction(this.production);

  void execute(ParsingContext context) {
    var node = new AstNode(
        production.lhs,
        context.reduced.sublist(context.reduced.length - production.rhs.length,
            context.reduced.length));
    context.reduced
      ..length -= node.children.length
      ..add(node);
  }
}

class AstNode {
  Nonterminal type;
  List children;

  AstNode(this.type, this.children);

  String toString() => '($type: ${children.join(", ")})';
}
