import 'dart:isolate';

import 'functions.dart';

void main(List<String> arguments) async {
  await Isolate.run(() {
    testMonero();
  });
  await Isolate.run(() {
    testWownero();
  });
}
