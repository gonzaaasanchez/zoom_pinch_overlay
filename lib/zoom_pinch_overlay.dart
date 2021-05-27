import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

//
// Transform widget enables the overlay to be updated dynamically
//
class TransformWidget extends StatefulWidget {
  final Widget child;
  final Matrix4 matrix;

  const TransformWidget({Key? key, required this.child, required this.matrix})
      : super(key: key);

  @override
  _TransformWidgetState createState() => _TransformWidgetState();
}

class _TransformWidgetState extends State<TransformWidget> {
  Matrix4? _matrix = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: (widget.matrix * _matrix),
      child: widget.child,
    );
  }

  void setMatrix(Matrix4? matrix) {
    setState(() {
      _matrix = matrix;
    });
  }
}

//
// ZoomOverlay enables a image to have full screen drag, pinch and zoom
//
class ZoomOverlay extends StatefulWidget {
  final Widget child;
  final double? minScale;
  final double? maxScale;

  const ZoomOverlay(
      {Key? key, required this.child, this.minScale, this.maxScale})
      : super(key: key);

  @override
  _ZoomOverlayState createState() => _ZoomOverlayState();
}

class _ZoomOverlayState extends State<ZoomOverlay>
    with TickerProviderStateMixin {
  Matrix4? _matrix = Matrix4.identity();
  late Offset _startFocalPoint;
  late Animation<Matrix4> _animationReset;
  late AnimationController _controllerReset;
  OverlayEntry? _overlayEntry;
  bool _isZooming = false;
  Matrix4 _transformMatrix = Matrix4.identity();

  final _transformWidget = GlobalKey<_TransformWidgetState>();

  @override
  void initState() {
    super.initState();

    _controllerReset =
        AnimationController(vsync: this, duration: Duration(milliseconds: 100));

    _controllerReset.addListener(() {
      _transformWidget.currentState!.setMatrix(_animationReset.value);
    });

    _controllerReset.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        hide();
      }
    });
  }

  @override
  void dispose() {
    _controllerReset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        onScaleEnd: onScaleEnd,
        child: Opacity(opacity: _isZooming ? 0 : 1, child: widget.child));
  }

  void onScaleStart(ScaleStartDetails details) {
    //Dont start the effect if the image havent reset complete.
    if (_controllerReset.isAnimating) return;
    _startFocalPoint = details.focalPoint;

    _matrix = Matrix4.identity();

    // create an matrix of where the image is on the screen for the overlay
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset position = renderBox.localToGlobal(Offset.zero);

    _transformMatrix =
        Matrix4.translation(Vector3(position.dx, position.dy, 0));

    show();

    setState(() {
      _isZooming = true;
    });
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isZooming || _controllerReset.isAnimating) return;

    Offset translationDelta = details.focalPoint - _startFocalPoint;

    Matrix4 translate = Matrix4.translation(
        Vector3(translationDelta.dx, translationDelta.dy, 0));

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset focalPoint =
        renderBox.globalToLocal(details.focalPoint - translationDelta);

    double scaleby = details.scale;
    if (widget.minScale != null && scaleby < widget.minScale!)
      scaleby = this.widget.minScale ?? 0;

    if (widget.maxScale != null && scaleby > widget.maxScale!)
      scaleby = this.widget.maxScale ?? 0;

    var dx = (1 - scaleby) * focalPoint.dx;
    var dy = (1 - scaleby) * focalPoint.dy;

    Matrix4 scale =
        Matrix4(scaleby, 0, 0, 0, 0, scaleby, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);

    _matrix = translate * scale;

    if (_transformWidget.currentState != null)
      _transformWidget.currentState!.setMatrix(_matrix);
  }

  void onScaleEnd(ScaleEndDetails details) {
    if (!_isZooming || _controllerReset.isAnimating) return;
    _animationReset = Matrix4Tween(begin: _matrix, end: Matrix4.identity())
        .animate(_controllerReset);
    _controllerReset.reset();
    _controllerReset.forward();
  }

  Widget _build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          TransformWidget(
            key: _transformWidget,
            matrix: _transformMatrix,
            child: widget.child,
          )
        ],
      ),
    );
  }

  void show() async {
    if (!_isZooming) {
      final overlayState = Overlay.of(context);
      _overlayEntry = OverlayEntry(builder: _build);
      overlayState?.insert(_overlayEntry!);
    }
  }

  void hide() async {
    setState(() {
      _isZooming = false;
    });

    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}