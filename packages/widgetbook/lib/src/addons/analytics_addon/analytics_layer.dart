import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'analytics_addon.dart';
import 'analytics_marker.dart';

/// Wraps the use case and draws the [AnalyticsAddon]'s toggle and cards.
///
/// The cards live in the root [Overlay], not next to the use case, so they
/// stay above bottom sheets and dialogs the use case opens on its own
/// navigator.
@internal
class AnalyticsLayer extends StatefulWidget {
  const AnalyticsLayer({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.resolve,
    required this.rescanInterval,
    required this.color,
    required this.child,
    this.refresh,
  });

  final bool enabled;
  final void Function(BuildContext context, bool enabled) onToggle;
  final AnalyticsResolver resolve;
  final Listenable? refresh;
  final Duration rescanInterval;
  final Color color;
  final Widget child;

  @override
  State<AnalyticsLayer> createState() => _AnalyticsLayerState();
}

class _AnalyticsLayerState extends State<AnalyticsLayer> {
  final _area = GlobalKey();
  final _scene = ValueNotifier(const _Scene.empty());
  OverlayEntry? _entry;
  OverlayState? _overlay;
  Timer? _timer;
  bool _scanRequested = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.rescanInterval, (_) => _scan());
    widget.refresh?.addListener(_requestScan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _insert();
      _scan();
    });
  }

  @override
  void didUpdateWidget(AnalyticsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_requestScan);
      widget.refresh?.addListener(_requestScan);
    }
    if (oldWidget.enabled != widget.enabled) _requestScan();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.refresh?.removeListener(_requestScan);
    _entry?.remove();
    _entry?.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _insert() {
    if (!mounted) return;
    _overlay = Overlay.maybeOf(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => _AnalyticsScene(
        scene: _scene,
        color: widget.color,
        onToggle: () => widget.onToggle(context, !widget.enabled),
      ),
    );
    _overlay?.insert(_entry!);
  }

  /// Scans after the current frame, once however often it is requested. The
  /// app may notify [AnalyticsLayer.refresh] while widgets are building.
  void _requestScan() {
    if (_scanRequested) return;
    _scanRequested = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _scanRequested = false;
        _scan();
      })
      ..scheduleFrame();
  }

  void _scan() {
    if (!mounted) return;
    final overlayBox = _overlay?.context.findRenderObject();
    final areaBox = _area.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox ||
        areaBox is! RenderBox ||
        !overlayBox.attached ||
        !areaBox.attached ||
        !areaBox.hasSize) {
      return;
    }

    Rect? rectOf(RenderObject? box) {
      if (box is! RenderBox || !box.attached || !box.hasSize) return null;
      return MatrixUtils.transformRect(
        box.getTransformTo(overlayBox),
        Offset.zero & box.size,
      );
    }

    final markers = widget.enabled
        ? widget.resolve(context)
        : const <AnalyticsMarker>[];
    final scene = _Scene(
      area: rectOf(areaBox),
      enabled: widget.enabled,
      markers: [
        for (final marker in markers)
          (
            marker: marker,
            anchor: marker.target != null && marker.target!.mounted
                ? rectOf(marker.target!.renderObject)
                : null,
          ),
      ],
    );
    if (!scene.sameAs(_scene.value)) _scene.value = scene;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _area, child: widget.child);
  }
}

typedef _Placed = ({AnalyticsMarker marker, Rect? anchor});

@immutable
class _Scene {
  const _Scene({
    required this.area,
    required this.enabled,
    required this.markers,
  });

  const _Scene.empty() : area = null, enabled = false, markers = const [];

  /// The workbench, in root overlay coordinates.
  final Rect? area;
  final bool enabled;

  /// Markers with the rect of their target, in root overlay coordinates.
  final List<_Placed> markers;

  /// Whether [other] would draw the same, so rescans that find nothing new do
  /// not rebuild the overlay.
  bool sameAs(_Scene other) {
    if (area != other.area ||
        enabled != other.enabled ||
        markers.length != other.markers.length) {
      return false;
    }
    for (var i = 0; i < markers.length; i++) {
      final (marker: a, anchor: aAnchor) = markers[i];
      final (marker: b, anchor: bAnchor) = other.markers[i];
      if (aAnchor != bAnchor ||
          a.id != b.id ||
          a.title != b.title ||
          a.badge != b.badge ||
          a.color != b.color ||
          !mapEquals(a.properties, b.properties)) {
        return false;
      }
    }
    return true;
  }
}

/// Size and spacing of the cards. Heights are fixed (one line per property)
/// so cards can be stacked before they are laid out.
abstract final class _Card {
  static const width = 260.0;
  static const padding = 12.0;
  static const border = 1.5;
  static const headerHeight = 20.0;
  static const headerGap = 8.0;
  static const rowHeight = 18.0;
  static const maxRows = 8;
  static const gap = 10.0;
  static const margin = 16.0;

  /// Room left free under the right column for the toggle.
  static const toggleRoom = 56.0;

  static int rowsOf(AnalyticsMarker marker) {
    final count = marker.properties.length;
    return count > maxRows ? maxRows : count;
  }

  static double heightOf(AnalyticsMarker marker) {
    final rows = rowsOf(marker);
    return (padding + border) * 2 +
        headerHeight +
        (rows == 0 ? 0 : headerGap + rows * rowHeight);
  }
}

class _AnalyticsScene extends StatefulWidget {
  const _AnalyticsScene({
    required this.scene,
    required this.color,
    required this.onToggle,
  });

  final ValueListenable<_Scene> scene;
  final Color color;
  final VoidCallback onToggle;

  @override
  State<_AnalyticsScene> createState() => _AnalyticsSceneState();
}

class _AnalyticsSceneState extends State<_AnalyticsScene> {
  final _dragged = <String, Offset>{};
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Scene>(
      valueListenable: widget.scene,
      builder: (context, scene, _) {
        final area = scene.area;
        if (area == null) return const SizedBox.shrink();

        final cards = scene.enabled
            ? _layout(scene.markers, area)
            : const <_LaidOut>[];

        // Overlay entries have no Material above them, so text would fall
        // back to the debug style.
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: area,
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IgnorePointer(
                        child: CustomPaint(
                          size: area.size,
                          painter: _ConnectorPainter(
                            cards: cards,
                            hovered: _hovered,
                            fallbackColor: widget.color,
                          ),
                        ),
                      ),
                      for (final card in cards)
                        Positioned(
                          left: card.position.dx,
                          top: card.position.dy,
                          child: _MarkerCard(
                            key: ValueKey(card.marker.id),
                            marker: card.marker,
                            color: card.marker.color ?? widget.color,
                            highlighted: _hovered == card.marker.id,
                            onHover: (hovering) => setState(
                              () => _hovered = hovering ? card.marker.id : null,
                            ),
                            onDrag: (delta) => setState(
                              () => _dragged[card.marker.id] =
                                  (_dragged[card.marker.id] ?? Offset.zero) +
                                  delta,
                            ),
                            onReset: () =>
                                setState(() => _dragged.remove(card.marker.id)),
                          ),
                        ),
                      Positioned(
                        right: _Card.margin,
                        bottom: _Card.margin,
                        child: _Toggle(
                          enabled: scene.enabled,
                          count: scene.markers.length,
                          color: widget.color,
                          onTap: widget.onToggle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Places the cards, in [area] coordinates, in a column at each side of
  /// the workbench so the use case stays visible. A card goes to the side
  /// nearer its target, or to the other one when that column is full; cards
  /// without a target start the left column. Each column is stacked top to
  /// bottom in target order without overlaps, then the user's drag offsets
  /// are added.
  List<_LaidOut> _layout(List<_Placed> placed, Rect area) {
    final bounds = Offset.zero & area.size;
    final items =
        [
          for (final item in placed)
            (
              item: item,
              anchor: switch (item.anchor?.shift(-area.topLeft)) {
                final anchor? when anchor.overlaps(bounds) => anchor,
                _ => null,
              },
            ),
        ]..sort((a, b) {
          final ay = a.anchor?.center.dy ?? double.negativeInfinity;
          final by = b.anchor?.center.dy ?? double.negativeInfinity;
          return ay.compareTo(by);
        });

    final cards = <_LaidOut>[];
    final bottoms = {
      false: _Card.margin - _Card.gap,
      true: _Card.margin - _Card.gap,
    };

    for (final (:item, :anchor) in items) {
      final height = _Card.heightOf(item.marker);
      final prefersRight = anchor != null && anchor.center.dx > area.width / 2;

      // Where the card would go in a column: level with its target, below
      // the cards above it, and lifted to end before the column's bottom if
      // there is room. Null if it does not fit.
      double? slotIn({required bool right}) {
        final top = bottoms[right]! + _Card.gap;
        final limit =
            area.height - _Card.margin - (right ? _Card.toggleRoom : 0);
        final wanted = anchor == null ? top : anchor.center.dy - height / 2;
        final y = math.max(top, math.min(wanted, limit - height));
        return y + height <= limit ? y : null;
      }

      // When neither column has room, the card goes below the left column,
      // which has no toggle, and can be dragged into view.
      final preferred = slotIn(right: prefersRight);
      final other = preferred == null ? slotIn(right: !prefersRight) : null;
      final right = switch ((preferred, other)) {
        (_?, _) => prefersRight,
        (null, _?) => !prefersRight,
        (null, null) => false,
      };
      final y = preferred ?? other ?? bottoms[false]! + _Card.gap;
      bottoms[right] = y + height;
      final x = right ? area.width - _Card.margin - _Card.width : _Card.margin;

      cards.add(
        _LaidOut(
          marker: item.marker,
          anchor: anchor,
          position: Offset(x, y) + (_dragged[item.marker.id] ?? Offset.zero),
          size: Size(_Card.width, height),
        ),
      );
    }
    return cards;
  }
}

@immutable
class _LaidOut {
  const _LaidOut({
    required this.marker,
    required this.anchor,
    required this.position,
    required this.size,
  });

  final AnalyticsMarker marker;
  final Rect? anchor;
  final Offset position;
  final Size size;

  Rect get rect => position & size;
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.cards,
    required this.hovered,
    required this.fallbackColor,
  });

  final List<_LaidOut> cards;
  final String? hovered;
  final Color fallbackColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final card in cards) {
      final anchor = card.anchor;
      if (anchor == null) continue;
      final color = card.marker.color ?? fallbackColor;
      final strong = card.marker.id == hovered;

      final target = RRect.fromRectAndRadius(
        anchor.inflate(3),
        const Radius.circular(8),
      );
      canvas
        ..drawRRect(
          target,
          Paint()..color = color.withValues(alpha: strong ? 0.18 : 0.08),
        )
        ..drawRRect(
          target,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strong ? 2.5 : 1.5
            ..color = color.withValues(alpha: strong ? 1 : 0.7),
        );

      final rect = card.rect;
      final cardOnRight = rect.center.dx >= anchor.center.dx;
      final start = cardOnRight
          ? Offset(anchor.right + 3, anchor.center.dy)
          : Offset(anchor.left - 3, anchor.center.dy);
      final end = cardOnRight
          ? Offset(rect.left, rect.center.dy)
          : Offset(rect.right, rect.center.dy);
      final pull = (end.dx - start.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + pull,
          start.dy,
          end.dx - pull,
          end.dy,
          end.dx,
          end.dy,
        );

      canvas
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strong ? 2.5 : 1.5
            ..color = color.withValues(alpha: strong ? 1 : 0.7),
        )
        ..drawCircle(start, strong ? 4 : 3, Paint()..color = color)
        ..drawCircle(end, strong ? 4 : 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => true;
}

class _MarkerCard extends StatelessWidget {
  const _MarkerCard({
    super.key,
    required this.marker,
    required this.color,
    required this.highlighted,
    required this.onHover,
    required this.onDrag,
    required this.onReset,
  });

  final AnalyticsMarker marker;
  final Color color;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onReset;

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final entries = marker.properties.entries.toList();
    final rows = _Card.rowsOf(marker);
    final hidden = entries.length - rows;
    final shown = hidden > 0 ? entries.take(rows - 1).toList() : entries;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        // Counts the drag from the press, so the card stays under the pointer.
        dragStartBehavior: DragStartBehavior.down,
        onPanUpdate: (details) => onDrag(details.delta),
        onDoubleTap: onReset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _Card.width,
          height: _Card.heightOf(marker),
          padding: const EdgeInsets.all(_Card.padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: highlighted ? 0.9 : 0.3),
              width: _Card.border,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(
                  alpha: highlighted ? 0.22 : 0.14,
                ),
                blurRadius: highlighted ? 28 : 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 11.5, color: _ink, height: 1.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _Card.headerHeight,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          marker.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (marker.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            marker.badge!,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rows > 0) const SizedBox(height: _Card.headerGap),
                for (final MapEntry(:key, :value) in shown)
                  SizedBox(
                    height: _Card.rowHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            key,
                            style: const TextStyle(color: _muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hidden > 0)
                  SizedBox(
                    height: _Card.rowHeight,
                    child: Text(
                      '+${hidden + 1} more',
                      style: const TextStyle(color: _muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.enabled,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final bool enabled;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? Colors.white : color;
    return Semantics(
      button: true,
      toggled: enabled,
      label: enabled ? 'Hide analytics' : 'Show analytics',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? color : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights_outlined, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
