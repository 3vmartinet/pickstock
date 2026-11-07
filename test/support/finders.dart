import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/ui/widgets/column_text.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Text containing [fragment], whether set as plain text or in newspaper
/// columns.
///
/// [find.textContaining] only sees text widgets, and a model's prose is set
/// by [ColumnText], which paints its own text.
Finder findProse(String fragment) => find.byWidgetPredicate(
  (widget) => switch (widget) {
    ColumnText(:final text) => text.contains(fragment),
    Text(:final data?) => data.contains(fragment),
    _ => false,
  },
  description: 'prose containing "$fragment"',
);
