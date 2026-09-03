import 'package:flutter/material.dart';

enum AnnotterMode {
  navigate,
  inspect,
  rectangle,
  pin,
}

class AnnotterItem {
  final int id;
  int number;
  Rect rect;
  String widgetName;
  List<String> hierarchy;
  String note;
  AnnotterMode mode;
  String screenName;
  bool isScrollable;
  double scrollOffsetAtCreation;

  AnnotterItem({
    required this.id,
    required this.number,
    required this.rect,
    this.widgetName = 'Element',
    this.hierarchy = const [],
    this.note = '',
    this.mode = AnnotterMode.inspect,
    this.screenName = 'HomeScreen',
    this.isScrollable = false,
    this.scrollOffsetAtCreation = 0.0,
  });

  AnnotterItem copy() {
    return AnnotterItem(
      id: id,
      number: number,
      rect: rect,
      widgetName: widgetName,
      hierarchy: List.from(hierarchy),
      note: note,
      mode: mode,
      screenName: screenName,
      isScrollable: isScrollable,
      scrollOffsetAtCreation: scrollOffsetAtCreation,
    );
  }

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
    'isScrollable': isScrollable,
  };
}
