part of sine_parser.src.grammar;

class _Superset<E extends GrammarSymbol> {
  final Expando<int> indices = new Expando<int>();
  final BuiltList<E> elements;

  _Superset(Iterable<E> source) : elements = new BuiltList<E>(source) {
    assert(elements.length == elements.toSet().length);
    for (var i = 0; i < elements.length; i++) {
      indices[elements[i]] = i;
    }
  }

  int indexOf(E symbol) {
    assert(indices[symbol] != null);
    return indices[symbol];
  }
}

///
class _SymbolSet<E extends GrammarSymbol> extends SetBase<E> {
  final _Superset<E> _superset;
  final Uint32List _storage;
  int _length;

  _SymbolSet(this._superset)
      : _storage = new Uint32List((_superset.elements.length / 32).ceil()),
        _length = 0;

  _SymbolSet.copy(this._superset, Uint32List storage, this._length)
      : _storage = new Uint32List.fromList(storage);

  bool _isSet(int index) => _storage[index ~/ 32] & (1 << index % 32) > 0;

  void _set(int index) {
    _storage[index ~/ 32] |= (1 << index % 32);
  }

  void _unset(int index) {
    _storage[index ~/ 32] &= ~(1 << index % 32);
  }

  bool add(E symbol) {
    var index = _superset.indexOf(symbol);
    if (_isSet(index)) return false;
    _set(index);
    _length++;
    return true;
  }

  int get length => _length;

  Iterator<E> get iterator => new _SymbolSetIterator<E>(this);

  bool contains(Object object) =>
      object is E && _isSet(_superset.indexOf(object));

  E lookup(Object symbol) => contains(symbol) ? symbol : null;

  bool remove(Object symbol) {
    if (symbol is! E) return false;
    var index = _superset.indexOf(symbol);
    if (!_isSet(index)) return false;
    _unset(index);
    _length--;
    return true;
  }

  Set<E> toSet() => new _SymbolSet.copy(_superset, _storage, _length);

  bool operator ==(other) =>
      other is _SymbolSet<E> &&
      other._superset == _superset &&
      const ListEquality<int>().equals(other._storage, _storage);

  int get hashCode => _storage.fold(_superset.hashCode, (a, b) => a ^ b);
}

class _SymbolSetIterator<E extends GrammarSymbol> extends Iterator<E> {
  final _SymbolSet<E> _set;
  int _progress = null;

  _SymbolSetIterator(this._set);

  E get current =>
      _progress != null && _progress < _set._superset.elements.length
          ? _set._superset.elements[_progress]
          : null;

  // TODO: Throw [ConcurrentModificationError]
  bool moveNext() {
    _progress ??= -1;
    while (++_progress < _set._superset.elements.length) {
      if (_set._isSet(_progress)) return true;
    }
    return false;
  }
}
