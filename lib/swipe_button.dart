library swipe_button;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

enum SwipePosition {
  SwipeLeft,
  SwipeRight,
}

const sliderPadding = EdgeInsets.all(8);

class SwipeController {
  AnimationController _controller;

  void _attachController(AnimationController controller) =>
      _controller = controller;

  void reset({Duration duration = const Duration(milliseconds: 600)}) {
    assert(_controller != null,
    'SwipeController was not attached to the SwipeButton');
    _controller.duration = duration;
    _controller.reverse();
  }
}

class SwipeButton extends StatefulWidget {
  const SwipeButton({
    Key key,
    this.thumb,
    this.content,
    BorderRadius borderRadius,
    this.initialPosition = SwipePosition.SwipeLeft,
    @required this.onChanged,
    this.swipeController,
    this.height = 56.0,
    this.rightValue = 0.5,
    this.color = Colors.deepPurpleAccent,
    this.thumbColor = Colors.pinkAccent,
  })  : assert(initialPosition != null && onChanged != null && height != null),
        this.borderRadius = borderRadius ?? BorderRadius.zero,
        super(key: key);

  final Widget thumb;
  final Widget content;
  final BorderRadius borderRadius;
  final double height;
  final SwipePosition initialPosition;
  final ValueChanged<SwipePosition> onChanged;
  final SwipeController swipeController;

  final Color color;
  final Color thumbColor;
  final double rightValue; // confirm value

  @override
  SwipeButtonState createState() => SwipeButtonState();
}

class SwipeButtonState extends State<SwipeButton>
    with SingleTickerProviderStateMixin {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _positionedKey = GlobalKey();

  AnimationController _controller;
  Animation<double> _contentAnimation;
  Offset _start = Offset.zero;

  RenderBox get _positioned => _positionedKey.currentContext.findRenderObject();

  RenderBox get _container => _containerKey.currentContext.findRenderObject();

  @override
  void initState() {
    super.initState();
    //_controller = AnimationController.unbounded(vsync: this);
    _controller = AnimationController(vsync: this);
    _contentAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.initialPosition == SwipePosition.SwipeRight) {
      _controller.value = 1.0;
    }
    widget.swipeController?._attachController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      //height: 100.0,
      height: widget.height,
      child: Stack(
        key: _containerKey,
        children: <Widget>[
          // added padding
          Padding(
            padding: sliderPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                //borderRadius: new BorderRadius.all(new Radius.circular(50.0)),
                borderRadius:
                    BorderRadius.all(Radius.circular(widget.height / 2)),
              ),
              child: ClipRRect(
                clipper: _SwipeButtonClipper(
                  animation: _controller,
                  borderRadius: widget.borderRadius,
                ),
                borderRadius: widget.borderRadius,
                child: SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.only(left: widget.height),
                    child: FadeTransition(
                      opacity: _contentAnimation,
                      child: widget.content,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget child) {
              return Align(
                alignment: Alignment((_controller.value * 2.0) - 1.0, 0.0),
                child: child,
              );
            },
            child: GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Container(
                key: _positionedKey,
                //width: 100,
                //height: 100,
                width: widget.height,
                height: widget.height,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.thumbColor,
                  // added shadow
                  boxShadow: [
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2.0, // has the effect of softening the shadow
                      spreadRadius:
                          2.0, // has the effect of extending the shadow
                      offset: Offset(1.0, 2.0),
                    )
                  ],
                ),
                child: widget.thumb,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    final pos = _positioned.globalToLocal(details.globalPosition);
    _start = Offset(pos.dx, 0.0);
    _controller.stop(canceled: true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final pos = _container.globalToLocal(details.globalPosition) - _start;
    final extent = _container.size.width - _positioned.size.width;
    _controller.value = (pos.dx.clamp(0.0, extent) / extent);
  }

  void _onDragEnd(DragEndDetails details) {
    final extent = _container.size.width - _positioned.size.width;
    var fractionalVelocity = (details.primaryVelocity / extent).abs();
    if (fractionalVelocity < 0.5) {
      fractionalVelocity = 0.5;
    }
    SwipePosition result;
    double acceleration, velocity;
    if (_controller.value > widget.rightValue) {
      acceleration = 0.5;
      velocity = fractionalVelocity;
      result = SwipePosition.SwipeRight;
    } else {
      acceleration = -0.5;
      velocity = -fractionalVelocity;
      result = SwipePosition.SwipeLeft;
    }
    final simulation = _SwipeSimulation(
      acceleration,
      _controller.value,
      1.0,
      velocity,
    );
    _controller.animateWith(simulation).then((_) {
      if (widget.onChanged != null) {
        widget.onChanged(result);
      }
    });
  }
}

class _SwipeSimulation extends GravitySimulation {
  _SwipeSimulation(
      double acceleration, double distance, double endDistance, double velocity)
      : super(acceleration, distance, endDistance, velocity);

  @override
  double x(double time) => super.x(time).clamp(0.0, 1.0);

  @override
  bool isDone(double time) {
    final _x = x(time).abs();
    return _x <= 0.0 || _x >= 1.0;
  }
}

class _SwipeButtonClipper extends CustomClipper<RRect> {
  const _SwipeButtonClipper({
    @required this.animation,
    @required this.borderRadius,
  })  : assert(animation != null && borderRadius != null),
        super(reclip: animation);

  final Animation<double> animation;
  final BorderRadius borderRadius;

  @override
  RRect getClip(Size size) {
    return borderRadius.toRRect(
      Rect.fromLTRB(
        size.width * animation.value,
        0.0,
        size.width,
        size.height,
      ),
    );
  }

  @override
  bool shouldReclip(_SwipeButtonClipper oldClipper) => true;
}
