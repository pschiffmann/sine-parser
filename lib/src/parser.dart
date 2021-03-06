import 'package:built_collection/built_collection.dart';
import 'package:tuple/tuple.dart' show Tuple2;
import 'grammar.dart';

class Parser {
  final BuiltList<BuiltList<ParserAction>> actions;

  Parser(this.actions);

  Object parse(Iterable<Terminal> input) {
    var context = new ParsingContext(this, input.iterator);
    context.actions.add(new ExpandAction(0));

    try {
      while (context.actions.isNotEmpty) {
        context.actions.removeLast().execute(context);
      }
    } catch (e) {
      print("reduced: ${context.reduced}");
      print("actions: ${context.actions.reversed.join('\n')}");
      throw e;
    }

    if (context.reduced.length != 1)
      throw new Exception("action stack is empty, but reduced stack is not "
          "- that's a bug in the parser generator :(");
    if (context.tokens.current != Terminal.endOfInput)
      throw new Exception("action stack is empty, but input is not exhausted "
          "- that's a bug in the parser generator :(");

    return context.reduced.first;
  }
}

class ParsingContext {
  final Parser parser;

  final Iterator<Terminal> tokens;
  final List reduced = [];
  final List<ParserAction> actions = [];
  final List<Tuple2<ParserAction, int>> marked = [];
  Nonterminal lastReduced;

  ParsingContext(this.parser, this.tokens) {
    tokens.moveNext();
  }
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

  String toString() => 's($terminal)';
}

class ExpandAction extends ParserAction {
  final int action;

  ExpandAction(this.action);

  void execute(ParsingContext context) {
    context.actions.addAll(context.parser.actions[action].reversed);
  }

  String toString() => 'e($action)';
}

class LookAheadAction extends ParserAction {
  final BuiltMap<Terminal, ParserAction> branches;

  LookAheadAction(this.branches);

  void execute(ParsingContext context) {
    if (branches.containsKey(context.tokens.current)) {
      context.actions.add(branches[context.tokens.current]);
    } else if (branches.containsKey(Terminal.emptyWord)) {
      context.actions.add(branches[Terminal.emptyWord]);
    } else {
      throw new Exception("Input rejected at token `${context.tokens.current}`,"
          " expected one of ${branches.keys.toList()}");
    }
  }

  String toString() => 'l$branches';
}

class ContinueAction extends ParserAction {
  final BuiltMap<Nonterminal, ParserAction> branches;

  ContinueAction(this.branches);

  void execute(ParsingContext context) {
    if (branches.containsKey(context.lastReduced))
      context.actions.add(branches[context.lastReduced]);
    else if (context.actions.isNotEmpty)
      throw new Exception("Can't execute a continuation, which should only "
          "happen when the parser is done. But there are still actions on "
          "the parser stack!");
  }

  String toString() => 'c$branches';
}

class ReduceAction extends ParserAction {
  final Production production;

  ReduceAction(this.production);

  void execute(ParsingContext context) {
    var node = new AstNode(
        production.lhs,
        context.reduced.sublist(context.reduced.length - production.rhs.length,
            context.reduced.length));
    context.reduced
      ..length -= node.children.length
      ..add(node);

    context.lastReduced = production.lhs;
    if (context.marked.isNotEmpty) {
      while (context.marked.last.item2 >= context.reduced.length)
        context.marked.removeLast();
      context.actions.add(context.marked.last.item1);
    }
  }

  String toString() => 'r($production)';
}

class MarkAction extends ParserAction {
  final ParserAction action;

  MarkAction(this.action);

  void execute(ParsingContext context) {
    context.marked.add(new Tuple2(action, context.reduced.length));
  }

  String toString() => 'm($action)';
}

class AstNode {
  Nonterminal type;
  List children;

  AstNode(this.type, this.children);

  String toString() {
    final result = new StringBuffer();
    final stack = <Map>[];

    void put(List children) {
      if (children.isNotEmpty) stack.add({'children': children, 'progress': 0});
    }

    bool isLastChild(Map level) {
      return level['progress'] == level['children'].length;
    }

    result.writeln(type);
    put(children);

    while (stack.isNotEmpty) {
      final node = stack.last['children'][stack.last['progress']++];

      result
        ..writeAll(stack
            .take(stack.length - 1)
            .map((level) => isLastChild(level) ? '   ' : ' │ '))
        ..write(isLastChild(stack.last) ? ' └╴' : ' ├╴');

      if (node is AstNode) {
        result.writeln(node.type);
        put(node.children);
      } else {
        result.writeln(node);
      }

      while (stack.isNotEmpty && isLastChild(stack.last)) {
        stack.removeLast();
      }
    }

    return result.toString();
  }
}
