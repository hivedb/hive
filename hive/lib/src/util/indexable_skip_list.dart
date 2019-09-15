import 'dart:collection';
import 'dart:math';

class IndexableSkipList<K, V> {
  static const maxHeight = 12;

  final Node<K, V> _head = Node(
    null,
    null,
    List(maxHeight),
    List.filled(maxHeight, 0),
  );

  final Random random;

  final Comparator<K> comparator;

  final bool overrideExisting;

  int _height = 1;

  int _length = 0;

  IndexableSkipList(this.comparator, this.overrideExisting, [Random random])
      : random = random ?? Random();

  int get length => _length;

  Iterable<K> get keys => _KeyIterable(_head);

  Iterable<V> get values => _ValueIterable(_head);

  void insert(K key, V value) {
    if (overrideExisting) {
      var node = _getNode(key);
      if (node != null) {
        node.value = value;
        return;
      }
    }

    // calculate this new node's level
    var newLevel = 0;
    while (random.nextBool() && newLevel < maxHeight) {
      newLevel++;
    }
    if (newLevel > _height) {
      newLevel = ++_height;
    }

    var newNode = Node<K, V>(
      key,
      value,
      List(newLevel + 1),
      List.filled(newLevel + 1, 0),
    );

    var current = _head;
    // Next & Down
    for (var level = _height - 1; level >= 0; level--) {
      while (true) {
        var next = current.next[level];
        if (next == null || comparator(key, next.key) < 0) break;
        current = next;
      }

      // CHANGE 1 - Increase all the above node's width by 1
      if (level > newLevel) {
        var next = current.next[level];
        if (next != null) {
          next.width[level]++;
        }
        continue;
      }

      if (level == 0) {
        // CHANGE 2 - Nodes at level 0 always have a width of 1
        newNode.width[0] = 1;
      } else {
        // CHANGE 3 - Calculate the width of the level
        var width = 0;
        var node = current.next[level - 1];
        while (node != null && comparator(key, node.key) >= 0) {
          width += node.width[level - 1];
          node = node.next[level - 1];
        }

        for (var j = level; j <= newLevel; j++) {
          newNode.width[j] += width;
        }
        newNode.width[level] += 1;
      }

      // Insert new node at the correct position in this level
      newNode.next[level] = current.next[level];
      current.next[level] = newNode;
    }

    // CHANGE 4 - Adjust the width of all next nodes
    for (var i = 1; i <= newLevel; i++) {
      var next = newNode.next[i];
      if (next != null) {
        next.width[i] -= newNode.width[i] - 1;
      }
    }

    _length++;
  }

  V delete(K key) {
    var node = _getNode(key);
    if (node == null) return null;

    var current = _head;
    // Next & Down
    for (var level = _height - 1; level >= 0; level--) {
      while (true) {
        var next = current.next[level];
        if (next == null || comparator(key, next.key) <= 0) break;
        current = next;
      }

      if (level > node.level) {
        var next = current.next[level];
        if (next != null) {
          next.width[level]--;
        }
      } else {
        current.next[level] = node.next[level];
        var next = node.next[level];
        if (next != null) {
          next.width[level] += node.width[level] - 1;
        }
      }
    }

    if (node.level == _height &&
        _height > 1 &&
        _head.next[node.level] == null) {
      _height--;
    }

    _length--;
    return node.value;
  }

  V get(K key) => _getNode(key)?.value;

  bool containsKey(K key) => _getNode(key) != null;

  Node<K, V> _getNode(K key) {
    var prev = _head;
    Node<K, V> node;
    for (var i = _height - 1; i >= 0; i--) {
      node = prev.next[i];

      while (node != null && comparator(key, node.key) > 0) {
        prev = node;
        node = node.next[i];
      }
    }

    if (node != null && comparator(key, node.key) == 0) {
      return node;
    }
    return null;
  }

  V getAt(int index) {
    var prev = _head;
    Node<K, V> node;
    for (var level = _height - 1; level >= 0; level--) {
      node = prev.next[level];

      while (node != null && index >= node.width[level]) {
        index -= node.width[level];
        prev = node;
        node = node.next[level];
      }
    }

    return node.value;
  }

  void clear() {
    _height = 1;
    for (var i = 0; i < maxHeight; i++) {
      _head.next[i] = null;
    }
    _height = 1;
    _length = 0;
  }

  void draw() {
    var output = StringBuffer();
    output.writeln();

    for (var level = maxHeight - 1; level >= 0; level--) {
      if (_head.next[level] == null) {
        continue;
      }

      output.write(level.toString() + ": ");
      for (var node = _head.next[level];
          node != null;
          node = node.next[level]) {
        var width = node.width[level];
        output.write("--" +
            "------" * (width - 1) +
            node.key.toString() +
            "(" +
            width.toString() +
            ")");
      }
      output.writeln();
    }
    print(output.toString());
  }
}

class Node<K, V> {
  final K key;

  V value;

  final List<Node<K, V>> next;

  final List<int> width;

  int get level => next.length - 1;

  Node(this.key, this.value, this.next, this.width);
}

abstract class _Iterator<K, V, E> implements Iterator<E> {
  Node<K, V> node;

  _Iterator(this.node);

  @override
  bool moveNext() => (node = node.next[0]) != null;
}

class _KeyIterator<K, V> extends _Iterator<K, V, K> {
  _KeyIterator(Node<K, V> node) : super(node);

  @override
  K get current => node.key;
}

class _KeyIterable<K, V> extends IterableBase<K> {
  final Node<K, V> head;

  _KeyIterable(this.head);

  @override
  Iterator<K> get iterator => _KeyIterator(head);
}

class _ValueIterator<K, V> extends _Iterator<K, V, V> {
  _ValueIterator(Node<K, V> node) : super(node);

  @override
  V get current => node.value;
}

class _ValueIterable<K, V> extends IterableBase<V> {
  final Node<K, V> head;

  _ValueIterable(this.head);

  @override
  Iterator<V> get iterator => _ValueIterator(head);
}
