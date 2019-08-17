# Watch changes

If you want to get notified about changes in a box, you can subscribe to the `Stream` returned by `box.watch()`. Every `put()`, `putAll()`, `delete()` and `deleteAll()` operation will be broadcasted to that stream.

This can be very useful for Flutter apps: You can rebuild widgets every time the box changes.

```dart
var box = Hive.box('myBox');
box.watch().listen((key, val, deleted) {
  if (deleted) {
    print('$key has been deleted');
  } else {
    print('$key is now assigned to $val');
  }
});

box.put('someKey', 123); // > someKey is now assigned to 123
box.delete('someKey'); // > someKey has been deleted
```

If you specify the `key` parameter, you will be notified about all changes of a specific key.

```dart
box.watch(key: 'someKey').listen((key, val, deleted) {
    // ...
});
```