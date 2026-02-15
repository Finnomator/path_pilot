import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/editor/painters/foreground_painter.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/ir_read_timeline_painter.dart';
import 'package:path_pilot/editor/painters/line_painter.dart';
import 'package:path_pilot/editor/painters/line_painter_settings/line_painter_visibility_settings.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/timeline_painter.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../helper/geometry.dart';
import 'visualizer_image_exporter.dart';
import 'obstacles/obstacle.dart';

class InstructionsVisualizer extends Visualizer {
  const InstructionsVisualizer({
    super.key,
    required super.zoom,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required super.highlightedInstruction,
    required SimulationResult simulationResult,
    required super.time,
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.play,
    required super.onTogglePlay,
    required super.obstacles,
    required super.visibilitySettings,
    required super.onVisibilitySettingsChange,
    required super.onSpeedMultiplierChanged,
    required super.speedMultiplier,
    super.enableTimeInput,
  }) : super(
          simulationResult: simulationResult,
          robiStateType: RobiStateType.innerOuter,
        );
}

class IrVisualizer extends Visualizer {
  const IrVisualizer({
    super.key,
    required super.zoom,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required IrCalculatorResult irCalculatorResult,
    required super.irPathApproximation,
    required IrReadPainterSettings irReadPainterSettings,
    required super.currentMeasurement,
    required super.time,
    super.enableTimeInput = true,
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.visibilitySettings,
    required super.play,
    required super.onTogglePlay,
    required super.obstacles,
    required super.measurementTimeDelta,
    required super.onVisibilitySettingsChange,
    required super.onSpeedMultiplierChanged,
    required super.speedMultiplier,
  }) : super(
          irCalculatorResultAndSettings: (irCalculatorResult, irReadPainterSettings),
          robiStateType: RobiStateType.leftRight,
        );
}

class Visualizer extends StatelessWidget {
  final double totalTime;
  final RobiConfig robiConfig;
  final bool enableTimeInput;
  final RobiStateType robiStateType;
  final RobiState robiState;
  final List<Obstacle>? obstacles;
  final LinePainterVisibilitySettings visibilitySettings;
  final void Function(LinePainterVisibilitySettings newSettings) onVisibilitySettingsChange;

  // For InstructionsVisualizer
  final SimulationResult? simulationResult;
  final InstructionResult? highlightedInstruction;

  // For IrVisualizer
  final (IrCalculatorResult, IrReadPainterSettings)? irCalculatorResultAndSettings;
  final List<Vector2>? irPathApproximation;
  final Measurement? currentMeasurement;
  final double? measurementTimeDelta;

  final double zoom;
  final void Function(double newZoom, Offset newOffset, bool lockToRobi) onZoomChanged;

  final Offset offset;

  final bool lockToRobi;

  final double time;
  final void Function(double newTime, Offset newOffset) onTimeChanged;

  final bool play;
  final void Function(bool play) onTogglePlay;

  final double speedMultiplier;
  final void Function(double newSpeedMultiplier) onSpeedMultiplierChanged;

  static const double minZoom = 100;
  static const double maxZoom = 1000;

  static final double minScale = log(minZoom + 1) / log2;
  static final double maxScale = log(maxZoom + 1) / log2;

  const Visualizer({
    super.key,
    required this.zoom,
    required this.offset,
    required this.robiConfig,
    required this.lockToRobi,
    required this.totalTime,
    required this.robiStateType,
    required this.robiState,
    required this.time,
    required this.onZoomChanged,
    required this.onTimeChanged,
    required this.play,
    required this.onTogglePlay,
    required this.obstacles,
    required this.visibilitySettings,
    required this.onVisibilitySettingsChange,
    required this.onSpeedMultiplierChanged,
    required this.speedMultiplier,
    this.enableTimeInput = true,
    this.simulationResult,
    this.irCalculatorResultAndSettings,
    this.highlightedInstruction,
    this.irPathApproximation,
    this.currentMeasurement,
    this.measurementTimeDelta,
  });

  static double startZoom = (minZoom + maxZoom) / 2;
  static Offset startOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final totalTimeString = printDuration(Duration(milliseconds: (totalTime * 1000).toInt()), SettingsStorage.showMilliseconds);
    final timeString = printDuration(Duration(milliseconds: (time * 1000).toInt()), SettingsStorage.showMilliseconds);

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final oldScale = log(zoom + 1) / log2;
            final newScale = (oldScale - event.scrollDelta.dy / 250).clamp(minScale, maxScale);
            final newZoom = (pow(2, newScale) - 1).toDouble();
            final scaleDelta = log(newZoom + 1) / log2 - oldScale;
            final newOffset = offset * pow(2, scaleDelta).toDouble();
            onZoomChanged(newZoom, newOffset, lockToRobi);
          },
          child: GestureDetector(
            onScaleStart: (details) {
              startZoom = zoom;
              startOffset = details.localFocalPoint - offset;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount > 1) {
                final newZoom = (startZoom * details.scale).clamp(minZoom, maxZoom);
                final scaleDelta = (log(newZoom + 1) - log(zoom + 1)) / log2;
                final newOffset = offset * pow(2, scaleDelta).toDouble();
                onZoomChanged(newZoom, newOffset, lockToRobi);
              } else {
                onZoomChanged(zoom, details.localFocalPoint - startOffset, false);
              }
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: LinePainter(
                  robiState: robiState,
                  scale: zoom,
                  robiConfig: robiConfig,
                  simulationResult: simulationResult,
                  highlightedInstruction: highlightedInstruction,
                  irCalculatorResultAndSettings: irCalculatorResultAndSettings,
                  irPathApproximation: irPathApproximation,
                  offset: offset,
                  obstacles: obstacles,
                  visibilitySettings: visibilitySettings,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ForegroundPainter(
                      visibilitySettings: visibilitySettings,
                      scale: zoom,
                      simulationResult: simulationResult,
                      irCalculatorResultAndSettings: irCalculatorResultAndSettings,
                      currentMeasurement: currentMeasurement,
                      robiState: robiState,
                      robiStateType: robiStateType,
                      showDeveloperInfo: SettingsStorage.developerMode,
                    ),
                    child: Container(),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                    Theme.of(context).colorScheme.surface,
                  ],
                  stops: const [0, 1],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: timeLinePainter(),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            thumbShape: SliderComponentShape.noThumb,
                            trackHeight: 4,
                            overlayColor: Theme.of(context).colorScheme.primary,
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                          ),
                          child: Slider(
                            value: time,
                            onChanged: enableTimeInput ? (value) => onTimeChanged(value, offset) : null,
                            max: totalTime,
                            min: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.start,
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () => onTogglePlay(!play),
                              icon: Icon(play ? Icons.pause : Icons.play_arrow),
                              iconSize: 32,
                            ),
                            IconButton(
                              onPressed: () => onZoomChanged(zoom, offset, !lockToRobi),
                              icon: Icon(lockToRobi ? Icons.lock : Icons.lock_open),
                            ),
                            PopupMenuButton(
                              tooltip: "",
                              icon: Icon(
                                Icons.visibility,
                                color: Colors.grey[400],
                              ),
                              itemBuilder: (context) {
                                Widget createEntry(LinePainterVisibility v) => CheckedPopupMenuItem(
                                      value: visibilitySettings.isVisible(v),
                                      checked: visibilitySettings.isVisible(v),
                                      padding: EdgeInsets.zero,
                                      onTap: () {
                                        visibilitySettings.set(v, !visibilitySettings.isVisible(v));
                                        onVisibilitySettingsChange(visibilitySettings);
                                      },
                                      child: Text(LinePainterVisibilitySettings.nameOf(v)),
                                    );

                                final widgets = <PopupMenuEntry>[];
                                for (final v in visibilitySettings.availableUniversalSettings) {
                                  widgets.add(PopupMenuItem(child: createEntry(v)));
                                }

                                widgets.add(const PopupMenuDivider(height: 1));
                                for (final v in visibilitySettings.availableNonUniversalSettings) {
                                  widgets.add(PopupMenuItem(
                                    child: createEntry(v),
                                  ));
                                }

                                return widgets;
                              },
                            ),
                            PopupMenuButton(
                              tooltip: "",
                              itemBuilder: (context) {
                                return [
                                  PopupMenuItem(
                                    onTap: () => onZoomChanged(zoom, Offset.zero, false),
                                    child: const ListTile(
                                      leading: Icon(Icons.center_focus_strong),
                                      title: Text("Center"),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => VisualizerImageExporter(viz: this),
                                    )),
                                    child: const ListTile(
                                      leading: Icon(Icons.image),
                                      title: Text("Export as image"),
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              DropdownButton<double>(
                                value: speedMultiplier,
                                items: const [0.25, 0.5, 1.0, 2.0, 5.0, 10.0].map((e) => DropdownMenuItem(value: e, child: Text("$e x"))).toList(growable: false),
                                onChanged: (value) => onSpeedMultiplierChanged(value ?? 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  "$timeString / $totalTimeString",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget timeLinePainter() {
    const maxInstructions = 10000;
    const timelineSize = Size.fromHeight(15);

    if (simulationResult != null && simulationResult!.instructionResults.length <= maxInstructions) {
      return RepaintBoundary(
        key: ValueKey(simulationResult.hashCode + highlightedInstruction.hashCode),
        child: CustomPaint(
          size: timelineSize,
          painter: TimelinePainter(
            simResult: simulationResult!,
            highlightedInstruction: highlightedInstruction,
          ),
        ),
      );
    } else if (irCalculatorResultAndSettings != null && measurementTimeDelta != null && irCalculatorResultAndSettings!.$1.length <= maxInstructions) {
      return RepaintBoundary(
        key: ValueKey(irCalculatorResultAndSettings!.$1.hashCode),
        child: CustomPaint(
          size: timelineSize,
          painter: IrReadTimelinePainter(
            totalTime: totalTime,
            measurementsTimeDelta: measurementTimeDelta!,
          ),
        ),
      );
    }
    return const SizedBox();
  }
}

String printDuration(Duration duration, bool showMilliseconds) {
  String twoDigits(int n) => n.toString().padLeft(2, "0").substring(0, 2);
  String hours = duration.inHours.remainder(24).abs().toString();
  String minutes = duration.inMinutes.remainder(60).abs().toString();
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());

  String res = "$minutes:$twoDigitSeconds";

  if (duration.inHours > 0) {
    minutes = twoDigits(duration.inMinutes.remainder(60).abs());
    res = "$hours:$minutes:$twoDigitSeconds";
  }

  if (!showMilliseconds) return res;

  String twoDigitMilliseconds = twoDigits(duration.inMilliseconds.remainder(1000).abs());

  res = "$res.$twoDigitMilliseconds";
  return res;
}
