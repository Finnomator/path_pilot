import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_pilot/main.dart';
import 'package:vector_math/vector_math.dart' show Aabb2;

abstract class Obstacle {
  final Paint paint;

  static Paint get defaultPaint => Paint()..color = Colors.grey;

  const Obstacle({required this.paint});

  void draw(final Canvas canvas);

  ObstacleType get type;

  String get name => type.name;

  Map<String, dynamic> toJson();

  String get details;

  bool isVisible(final Aabb2 visibleArea);
}

class RectangleObstacle extends Obstacle {
  double x, y, w, h;

  RectangleObstacle({
    required super.paint,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  @override
  void draw(final Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(x, -y, w, h), paint);
  }

  RectangleObstacle.fromJson(Map<String, dynamic> json)
      : x = json["x"],
        y = json["y"],
        w = json["w"],
        h = json["h"],
        super(paint: Paint()..color = Color(json["color"]));

  @override
  Map<String, dynamic> toJson() => {
        "color": paint.color.toARGB32(),
        "x": x,
        "y": y,
        "w": w,
        "h": h,
      };

  @override
  ObstacleType get type => ObstacleType.rectangle;

  static RectangleObstacle base() => RectangleObstacle(paint: Obstacle.defaultPaint, x: -0.05, y: 0.05, w: 0.1, h: 0.1);

  @override
  String get details => "Top left corner: (${(x * 100).toStringAsFixed(2)}, ${(y * 100).toStringAsFixed(2)})cm\nWidth: ${(w * 100).toStringAsFixed(2)}cm\nHeight: ${(h * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Aabb2 visibleArea) => true;
}

class CircleObstacle extends Obstacle {
  double x, y;
  double radius;

  CircleObstacle({
    required super.paint,
    required this.x,
    required this.y,
    required this.radius,
  });

  @override
  void draw(final Canvas canvas) => canvas.drawCircle(Offset(x, -y), radius, paint);

  @override
  Map<String, dynamic> toJson() => {
        "color": paint.color.toARGB32(),
        "x": x,
        "y": y,
        "r": radius,
      };

  CircleObstacle.fromJson(Map<String, dynamic> json)
      : x = json["x"],
        y = json["y"],
        radius = json["r"],
        super(paint: Paint()..color = Color(json["color"]));

  @override
  ObstacleType get type => ObstacleType.circle;

  static CircleObstacle base() => CircleObstacle(paint: Obstacle.defaultPaint, x: 0, y: 0, radius: 0.1);

  @override
  String get details => "Center: (${(x * 100).toStringAsFixed(2)}, ${(y * 100).toStringAsFixed(2)})cm\nRadius: ${(radius * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Aabb2 visibleArea) {
    return true;
  }
}

class ImageObstacle extends Obstacle {
  double x, y, w, h;
  ui.Image? _image;
  String? _imagePath;

  ui.Image? get image => _image;

  String? get imagePath => _imagePath;

  Future<bool> setImg(String newImgPath) async {
    try {
      final bytes = await File(newImgPath).readAsBytes();
      _image = await decodeImageFromList(bytes);
      _imagePath = newImgPath;
    } catch (e, s) {
      logger.errorWithStackTrace("Failed to read and decode image '$newImgPath'", e, s);
      return false;
    }
    return true;
  }

  ImageObstacle({
    required super.paint,
    required this.w,
    required this.h,
    required this.x,
    required this.y,
    required ui.Image? img,
    required String? imgPath,
  })  : _image = img,
        _imagePath = imgPath;

  static Future<ImageObstacle?> create({
    required Paint paint,
    required double x,
    required double y,
    required double w,
    required double h,
    required String? imgPath,
  }) async {
    try {
      ui.Image? img;
      if (imgPath != null) {
        final bytes = await File(imgPath).readAsBytes();
        img = await decodeImageFromList(bytes);
      }
      return ImageObstacle(paint: paint, img: img, imgPath: imgPath, x: x, y: y, w: w, h: h);
    } catch (e, s) {
      logger.errorWithStackTrace("Failed to load image", e, s);
    }
    return null;
  }

  static Future<ImageObstacle?> fromJson(Map<String, dynamic> json) => ImageObstacle.create(
        paint: Paint()..color = Color(json["color"]),
        x: json["x"],
        y: json["y"],
        w: json["w"],
        h: json["h"],
        imgPath: json["img_path"],
      );

  @override
  String get details {
    if (image == null) return "Image not loaded";

    final sizeS = "Width: ${(w * 100).toStringAsFixed(2)}cm\nHeight: ${(h * 100).toStringAsFixed(2)}cm";

    return """
Top left corner: (${(x * 100).toStringAsFixed(2)}, ${(y * 100).toStringAsFixed(2)})cm
$sizeS
Image location: $_imagePath""";
  }

  @override
  void draw(Canvas canvas) {
    if (image == null) return;
    final sw = w / image!.width;
    final sh = h / image!.height;
    canvas.translate(x, -y);
    canvas.scale(sw, sh);
    canvas.drawImage(image!, Offset.zero, paint);
  }

  static Future<ImageObstacle> base() async => (await create(
        paint: Obstacle.defaultPaint,
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
        imgPath: null,
      ))!;

  @override
  bool isVisible(Aabb2 visibleArea) => true;

  @override
  Map<String, dynamic> toJson() {
    if (image == null) return {};
    return {
      "color": paint.color.toARGB32(),
      "x": x,
      "y": y,
      "img_path": _imagePath,
      "w": w,
      "h": h,
    };
  }

  @override
  ObstacleType get type => ObstacleType.image;
}

enum ObstacleType {
  rectangle("Rectangle", Icons.square),
  circle("Circle", Icons.circle),
  image("Image", Icons.image);

  final String name;
  final IconData icon;

  const ObstacleType(this.name, this.icon);

  factory ObstacleType.fromString(String s) {
    for (final element in ObstacleType.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("Unknown obstacle type");
  }
}
