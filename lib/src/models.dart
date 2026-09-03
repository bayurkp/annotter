import 'package:flutter/material.dart';

enum AnnotterMode {
  navigate,
  inspect,
  rectangle,
  pin,
}

class AnnotterItem {
  final int id;
  final int number;
  Rect rect;
  final String widgetName;
  final List<String> hierarchy;
  String note;
  final AnnotterMode mode;
  final String screenName;

  AnnotterItem({
    required this.id,
    required this.number,
    required this.rect,
    this.widgetName = 'Element',
    this.hierarchy = const [],
    this.note = '',
    this.mode = AnnotterMode.inspect,
    this.screenName = 'Current Screen',
  });

  // ponytail: Minimal map serialization.
  Map<String, dynamic> toJson() => {
    'number': number,
    'widgetName': widgetName,
    'screenName': screenName,
    'hierarchy': hierarchy,
    'position': {
      'x': rect.left.toInt(),
      'y': rect.top.toInt(),
      'width': rect.width.toInt(),
      'height': rect.height.toInt(),
    },
    'note': note,
    'mode': mode.name,
  };
}
