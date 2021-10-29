import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/rendering.dart';
import 'package:get_storage/get_storage.dart';

import '_image_painter.dart';
import '_ported_interactive_viewer.dart';
import 'widgets/_color_widget.dart';
import 'widgets/_mode_widget.dart';
import 'widgets/_range_slider.dart';

export '_image_painter.dart';

///[ImagePainter] widget.
@immutable
class ImagePainter extends StatefulWidget {
  const ImagePainter._(
      {Key? key,
      this.assetPath,
      this.networkUrl,
      this.byteArray,
      this.file,
      this.height,
      this.width,
      this.placeHolder,
      this.isScalable,
      this.brushIcon,
      this.clearAllIcon,
      this.colorIcon,
      this.undoIcon,
      this.isSignature = false,
      this.controlsAtTop = true,
      this.signatureBackgroundColor,
      this.colors,
      this.initialPaintMode,
      this.initialStrokeWidth,
      this.initialColor,
      this.onColorChanged,
      this.onStrokeWidthChanged,
      this.onPaintModeChanged})
      : super(key: key);

  ///Constructor for signature painting.
  factory ImagePainter.signature({
    required Key key,
    Color? signatureBgColor,
    double? height,
    double? width,
    List<Color>? colors,
    Widget? brushIcon,
    Widget? undoIcon,
    Widget? clearAllIcon,
    Widget? colorIcon,
    PaintMode? initialPaintMode,
    double? initialStrokeWidth,
    Color? initialColor,
    ValueChanged<PaintMode>? onPaintModeChanged,
    ValueChanged<Color>? onColorChanged,
    ValueChanged<double>? onStrokeWidthChanged,
  }) {
    return ImagePainter._(
      key: key,
      height: height,
      width: width,
      isSignature: true,
      isScalable: false,
      colors: colors,
      signatureBackgroundColor: signatureBgColor ?? Colors.white,
      brushIcon: brushIcon,
      undoIcon: undoIcon,
      colorIcon: colorIcon,
      clearAllIcon: clearAllIcon,
      onPaintModeChanged: onPaintModeChanged,
      onColorChanged: onColorChanged,
      onStrokeWidthChanged: onStrokeWidthChanged,
    );
  }

  ///Only accessible through [ImagePainter.network] constructor.
  final String? networkUrl;

  ///Only accessible through [ImagePainter.memory] constructor.
  final Uint8List? byteArray;

  ///Only accessible through [ImagePainter.file] constructor.
  final File? file;

  ///Only accessible through [ImagePainter.asset] constructor.
  final String? assetPath;

  ///Height of the Widget. Image is subjected to fit within the given height.
  final double? height;

  ///Width of the widget. Image is subjected to fit within the given width.
  final double? width;

  ///Widget to be shown during the conversion of provided image to [ui.Image].
  final Widget? placeHolder;

  ///Defines whether the widget should be scaled or not. Defaults to [false].
  final bool? isScalable;

  ///Flag to determine signature or image;
  final bool isSignature;

  ///Signature mode background color
  final Color? signatureBackgroundColor;

  ///List of colors for color selection
  ///If not provided, default colors are used.
  final List<Color>? colors;

  ///Icon Widget of strokeWidth.
  final Widget? brushIcon;

  ///Widget of Color Icon in control bar.
  final Widget? colorIcon;

  ///Widget for Undo last action on control bar.
  final Widget? undoIcon;

  ///Widget for clearing all actions on control bar.
  final Widget? clearAllIcon;

  ///Define where the controls is located.
  ///`true` represents top.
  final bool controlsAtTop;

  ///Initial PaintMode.
  final PaintMode? initialPaintMode;

  //the initial stroke width
  final double? initialStrokeWidth;

  //the initial color
  final Color? initialColor;

  final ValueChanged<Color>? onColorChanged;

  final ValueChanged<double>? onStrokeWidthChanged;

  final ValueChanged<PaintMode>? onPaintModeChanged;

  @override
  ImagePainterState createState() => ImagePainterState();
}

///
class ImagePainterState extends State<ImagePainter> {
  final _repaintKey = GlobalKey();
  ui.Image? _image;
  bool _inDrag = false;
  var _paintHistory = <PaintInfo>[];
  final _points = <Offset?>[];
  late final ValueNotifier<Controller> _controller;
  late final ValueNotifier<bool> _isLoaded;
  late final TextEditingController _textController;
  Offset? _start, _end;
  int _strokeMultiplier = 1;

  @override
  void initState() {
    super.initState();
    _isLoaded = ValueNotifier<bool>(false);
    loadHistory();
    _controller = ValueNotifier(const Controller().copyWith(
        mode: widget.initialPaintMode,
        strokeWidth: widget.initialStrokeWidth,
        color: widget.initialColor));
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _isLoaded.dispose();
    _textController.dispose();
    super.dispose();
  }

  Paint get _painter => Paint()
    ..color = _controller.value.color
    ..strokeWidth = _controller.value.strokeWidth * _strokeMultiplier
    ..style = _controller.value.mode == PaintMode.dashLine
        ? PaintingStyle.stroke
        : _controller.value.paintStyle;

  void loadHistory() {
    List<PaintInfo> History = [];
    dynamic localHistory = GetStorage().read('image');
    localHistory.forEach((element) {
      History.add(PaintInfo.fromJson(element));
    });
    _paintHistory = History;
  }

  @override
  Widget build(BuildContext context) {
    return _paintSignature();
  }

  Widget _paintSignature() {
    return Column(
      children: [
        _buildControls(),
        Stack(
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: ClipRect(
                child: Container(
                  width: widget.width ?? double.maxFinite,
                  height: widget.height ?? double.maxFinite,
                  child: ValueListenableBuilder<Controller>(
                    valueListenable: _controller,
                    builder: (_, controller, __) {
                      return ImagePainterTransformer(
                        panEnabled: false,
                        scaleEnabled: false,
                        onInteractionStart: _scaleStartGesture,
                        onInteractionUpdate: (details) =>
                            _scaleUpdateGesture(details, controller),
                        onInteractionEnd: (details) =>
                            _scaleEndGesture(details, controller),
                        child: CustomPaint(
                          willChange: true,
                          isComplex: true,
                          painter: DrawImage(
                            isSignature: true,
                            backgroundColor: widget.signatureBackgroundColor,
                            points: _points,
                            paintHistory: _paintHistory,
                            isDragging: _inDrag,
                            update: UpdatePoints(
                                start: _start,
                                end: _end,
                                painter: _painter,
                                mode: controller.mode),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  _scaleStartGesture(ScaleStartDetails onStart) {
    if (!widget.isSignature) {
      setState(() {
        _start = onStart.focalPoint;
        _points.add(_start);
      });
    }
  }

  ///Fires while user is interacting with the screen to record painting.
  void _scaleUpdateGesture(ScaleUpdateDetails onUpdate, Controller ctrl) {
    setState(
      () {
        _inDrag = true;
        _start ??= onUpdate.focalPoint;
        _end = onUpdate.focalPoint;
        if (ctrl.mode == PaintMode.freeStyle) _points.add(_end);
        if (ctrl.mode == PaintMode.text &&
            _paintHistory
                .where((element) => element.mode == PaintMode.text)
                .isNotEmpty) {
          _paintHistory
              .lastWhere((element) => element.mode == PaintMode.text)
              .offset = [_end];
        }
      },
    );
  }

  ///Fires when user stops interacting with the screen.
  void _scaleEndGesture(ScaleEndDetails onEnd, Controller controller) {
    setState(() {
      _inDrag = false;
      if (_start != null &&
          _end != null &&
          (controller.mode == PaintMode.freeStyle)) {
        _points.add(null);
        _addFreeStylePoints();
        _points.clear();
      } else if (_start != null &&
          _end != null &&
          controller.mode != PaintMode.text) {
        _addEndPoints();
      }
      _start = null;
      _end = null;
    });
  }

  void _addEndPoints() => _paintHistory.add(
        PaintInfo(
          offset: <Offset?>[_start, _end],
          painter: _painter,
          mode: _controller.value.mode,
        ),
      );

  void _addFreeStylePoints() => _paintHistory.add(
        PaintInfo(
          offset: <Offset?>[..._points],
          painter: _painter,
          mode: PaintMode.freeStyle,
        ),
      );

  ///Provides [ui.Image] of the recorded canvas to perform action.
  Future<ui.Image> _renderImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = DrawImage(image: _image, paintHistory: _paintHistory);
    final size = Size(_image!.width.toDouble(), _image!.height.toDouble());
    painter.paint(canvas, size);
    return recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
  }

  List<PaintInfo> storePaintHistory() {
    return _paintHistory;
  }

  PopupMenuItem _showOptionsRow(Controller controller) {
    return PopupMenuItem(
      enabled: false,
      child: Center(
        child: SizedBox(
          child: Wrap(
            children: paintModes
                .map(
                  (item) => SelectionItems(
                    data: item,
                    isSelected: controller.mode == item.mode,
                    onTap: () {
                      if (widget.onPaintModeChanged != null &&
                          item.mode != null) {
                        widget.onPaintModeChanged!(item.mode!);
                      }
                      _controller.value = controller.copyWith(mode: item.mode);
                      Navigator.of(context).pop();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  PopupMenuItem _showRangeSlider() {
    return PopupMenuItem(
      enabled: false,
      child: SizedBox(
        width: double.maxFinite,
        child: ValueListenableBuilder<Controller>(
          valueListenable: _controller,
          builder: (_, ctrl, __) {
            return RangedSlider(
              value: ctrl.strokeWidth,
              onChanged: (value) {
                _controller.value = ctrl.copyWith(strokeWidth: value);
                if (widget.onStrokeWidthChanged != null) {
                  widget.onStrokeWidthChanged!(value);
                }
              },
            );
          },
        ),
      ),
    );
  }

  PopupMenuItem _showColorPicker(Controller controller) {
    return PopupMenuItem(
        enabled: false,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: (widget.colors ?? editorColors).map((color) {
              return ColorItem(
                isSelected: color == controller.color,
                color: color,
                onTap: () {
                  _controller.value = controller.copyWith(color: color);
                  if (widget.onColorChanged != null) {
                    widget.onColorChanged!(color);
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ));
  }

  ///Generates [Uint8List] of the [ui.Image] generated by the [renderImage()] method.
  ///Can be converted to image file by writing as bytes.
  Future<Uint8List?> exportImage() async {
    late ui.Image _convertedImage;
    if (widget.isSignature) {
      final _boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      _convertedImage = await _boundary.toImage(pixelRatio: 3);
    } else if (widget.byteArray != null && _paintHistory.isEmpty) {
      return widget.byteArray;
    } else {
      _convertedImage = await _renderImage();
    }
    final byteData =
        await _convertedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.grey[200],
      child: Row(
        children: [
          ValueListenableBuilder<Controller>(
              valueListenable: _controller,
              builder: (_, _ctrl, __) {
                return PopupMenuButton(
                  tooltip: "Change mode",
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  icon: Icon(
                      paintModes
                          .firstWhere((item) => item.mode == _ctrl.mode)
                          .icon,
                      color: Colors.grey[700]),
                  itemBuilder: (_) => [_showOptionsRow(_ctrl)],
                );
              }),
          ValueListenableBuilder<Controller>(
              valueListenable: _controller,
              builder: (_, controller, __) {
                return PopupMenuButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  tooltip: "Change color",
                  icon: widget.colorIcon ??
                      Container(
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                          color: controller.color,
                        ),
                      ),
                  itemBuilder: (_) => [_showColorPicker(controller)],
                );
              }),
          PopupMenuButton(
            tooltip: "Change Brush Size",
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon:
                widget.brushIcon ?? Icon(Icons.brush, color: Colors.grey[700]),
            itemBuilder: (_) => [_showRangeSlider()],
          ),
          const Spacer(),
          IconButton(
              tooltip: "Undo",
              icon:
                  widget.undoIcon ?? Icon(Icons.reply, color: Colors.grey[700]),
              onPressed: () {
                if (_paintHistory.isNotEmpty) {
                  setState(_paintHistory.removeLast);
                }
              }),
          IconButton(
            tooltip: "Clear all progress",
            icon: widget.clearAllIcon ??
                Icon(Icons.clear, color: Colors.grey[700]),
            onPressed: () => setState(_paintHistory.clear),
          ),
        ],
      ),
    );
  }
}

///Gives access to manipulate the essential components like [strokeWidth], [Color] and [PaintMode].
@immutable
class Controller {
  ///Tracks [strokeWidth] of the [Paint] method.
  final double strokeWidth;

  ///Tracks [Color] of the [Paint] method.
  final Color color;

  ///Tracks [PaintingStyle] of the [Paint] method.
  final PaintingStyle paintStyle;

  ///Tracks [PaintMode] of the current [Paint] method.
  final PaintMode mode;

  ///Any text.
  final String text;

  ///Constructor of the [Controller] class.
  const Controller(
      {this.strokeWidth = 4.0,
      this.color = Colors.red,
      this.mode = PaintMode.line,
      this.paintStyle = PaintingStyle.stroke,
      this.text = ""});

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is Controller &&
        o.strokeWidth == strokeWidth &&
        o.color == color &&
        o.paintStyle == paintStyle &&
        o.mode == mode &&
        o.text == text;
  }

  @override
  int get hashCode {
    return strokeWidth.hashCode ^
        color.hashCode ^
        paintStyle.hashCode ^
        mode.hashCode ^
        text.hashCode;
  }

  ///copyWith Method to access immutable controller.
  Controller copyWith(
      {double? strokeWidth,
      Color? color,
      PaintMode? mode,
      PaintingStyle? paintingStyle,
      String? text}) {
    return Controller(
        strokeWidth: strokeWidth ?? this.strokeWidth,
        color: color ?? this.color,
        mode: mode ?? this.mode,
        paintStyle: paintingStyle ?? paintStyle,
        text: text ?? this.text);
  }
}
