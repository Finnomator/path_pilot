import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

import '../painters/robi_painter.dart';

class InstructionDetailsWidget extends StatefulWidget {
  final InstructionResult instructionResult;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;

  const InstructionDetailsWidget({
    super.key,
    required this.instructionResult,
    required this.robiConfig,
    required this.timeChangeNotifier,
  });

  @override
  State<InstructionDetailsWidget> createState() => _InstructionDetailsWidgetState();
}

class _InstructionDetailsWidgetState extends State<InstructionDetailsWidget> {
  static const iterations = 100;

  late XAxisType xAxisMode = widget.instructionResult is RapidTurnResult ? XAxisType.time : XAxisType.position;
  YAxisType yAxisMode = YAxisType.velocity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    bool isScreenWide = screenSize.width > screenSize.height;

    // Data Calculation
    final List<InnerOuterRobiState> chartStates = List.generate(
      iterations,
          (i) => getRobiStateAtTimeInInstructionResult(
        widget.instructionResult,
        i / (iterations - 1) * widget.instructionResult.totalTime,
      ),
      growable: false,
    );

    late final String xAxisTitle;
    late final String yAxisTitle;
    final angular = widget.instructionResult is! DriveResult;

    switch (xAxisMode) {
      case XAxisType.time:
        xAxisTitle = "Time (s)";
        break;
      case XAxisType.position:
        xAxisTitle = angular ? "Rotation (°)" : "Distance (cm)";
        break;
    }

    switch (yAxisMode) {
      case YAxisType.position:
        yAxisTitle = angular ? "Rotation (°)" : "Distance (cm)";
        break;
      case YAxisType.velocity:
        yAxisTitle = angular ? "Velocity (°/s)" : "Velocity (cm/s)";
        break;
      case YAxisType.acceleration:
        yAxisTitle = angular ? "Accel (°/s²)" : "Accel (cm/s²)";
        break;
    }

    final xSpots = xValues(widget.instructionResult, chartStates, xAxisMode);
    final ySpots = angular
        ? yAngularValues(widget.instructionResult, chartStates, yAxisMode)
        : yDriveResValues(widget.instructionResult as DriveResult, chartStates, yAxisMode);

    final spots = mergeData(xSpots, ySpots);

    // Scaling
    double minY = 0;
    double maxX = 0;

    switch (xAxisMode) {
      case XAxisType.time:
        maxX = widget.instructionResult.totalTime;
        break;
      case XAxisType.position:
        if (angular) {
          if (widget.instructionResult is RapidTurnResult) {
            maxX = (widget.instructionResult as RapidTurnResult).totalTurnDegree;
          } else {
            maxX = (widget.instructionResult as TurnResult).totalTurnDegree;
          }
        } else {
          maxX = (widget.instructionResult as DriveResult).totalDistance * 100;
        }
        break;
    }

    if (spots.isNotEmpty) {
      minY = spots.map((spot) => spot.y).reduce(min);
      if (minY > 0) minY = 0;
    }

    return Column(
      children: [
        // Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildMiniDropdown<XAxisType>(
              value: xAxisMode,
              items: XAxisType.values,
              onChanged: (v) => setState(() => xAxisMode = v ?? XAxisType.position),
              label: "X",
            ),
            const SizedBox(width: 8),
            _buildMiniDropdown<YAxisType>(
              value: yAxisMode,
              items: YAxisType.values,
              onChanged: (v) => setState(() => yAxisMode = v ?? YAxisType.velocity),
              label: "Y",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        AspectRatio(
          aspectRatio: isScreenWide ? 2.0 : 1.5,
          child: ListenableBuilder(
            listenable: widget.timeChangeNotifier,
            builder: (context, child) {
              double? progress = (widget.timeChangeNotifier.time - widget.instructionResult.timeStamp) / widget.instructionResult.totalTime;
              if (progress > 1 || progress < 0) progress = null;

              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(color: theme.dividerColor.withOpacity(0.2), strokeWidth: 1),
                    getDrawingVerticalLine: (value) => FlLine(color: theme.dividerColor.withOpacity(0.2), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: minY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => theme.colorScheme.surfaceContainerHighest,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          return LineTooltipItem(
                            "${touchedSpot.y.toStringAsFixed(1)}",
                            TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: theme.hintColor, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(xAxisTitle, style: TextStyle(fontSize: 10, color: theme.hintColor)),
                      axisNameSize: 20,
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == maxX) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(value.toInt().toString(), style: TextStyle(color: theme.hintColor, fontSize: 10)),
                            );
                          }
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isStepLineChart: yAxisMode == YAxisType.acceleration,
                      spots: spots,
                      color: theme.colorScheme.primary,
                      barWidth: 2,
                      isCurved: yAxisMode != YAxisType.acceleration,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  extraLinesData: progress == null
                      ? null
                      : ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: getProgressIndicatorX(progress, maxX),
                        color: theme.colorScheme.secondary,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDropdown<T>({required T value, required List<T> items, required ValueChanged<T?> onChanged, required String label}) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          isDense: true,
          style: Theme.of(context).textTheme.bodySmall,
          onChanged: onChanged,
          items: items.map((item) {
            // Extract label from enum if possible, else toString
            String text = item.toString().split('.').last;
            if (item is XAxisType) text = item.label;
            if (item is YAxisType) text = item.label;

            return DropdownMenuItem<T>(value: item, child: Text("$label: $text"));
          }).toList(),
        ),
      ),
    );
  }

  double getProgressIndicatorX(final double progress, final double maxX) {
    switch (xAxisMode) {
      case XAxisType.time:
        return progress * maxX;
      case XAxisType.position:
        final rs = getRobiStateAtTimeInInstructionResult(widget.instructionResult, progress * widget.instructionResult.totalTime);
        if (widget.instructionResult is! DriveResult) {
          return rs.rotation - widget.instructionResult.startRotation;
        }
        return rs.position.distanceTo(widget.instructionResult.startPosition) * 100;
    }
  }

  List<double> xValues(final InstructionResult res, final List<InnerOuterRobiState> states, final XAxisType xAxis) {
    return states.map((state) {
      if (xAxis == XAxisType.time) {
        return state.timeStamp - res.timeStamp;
      } else if (res is! DriveResult) {
        return (state.rotation - res.startRotation).abs();
      } else {
        return res.startPosition.distanceTo(state.position) * 100;
      }
    }).toList();
  }

  List<double> yAngularValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    if (res is DriveResult) {
      throw Exception("Cannot use angular values for DriveResult");
    }

    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = (state.rotation - res.startRotation).abs();
          break;
        case YAxisType.velocity:
          if (res is TurnResult) {
            y = (state.outerVelocity - state.innerVelocity) / widget.robiConfig.trackWidth * (180 / pi);
          } else if (res is RapidTurnResult) {
            y = state.outerVelocity / (widget.robiConfig.trackWidth * pi) * 360;
          }
          break;
        case YAxisType.acceleration:
          if (res is TurnResult) {
            y = (state.outerAcceleration - state.innerAcceleration) / widget.robiConfig.trackWidth * (180 / pi);
          } else if (res is RapidTurnResult) {
            y = state.outerAcceleration / (widget.robiConfig.trackWidth * pi) * 360;
          }
          break;
      }

      return y;
    }).toList();
  }

  List<double> yDriveResValues(final DriveResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = state.position.distanceTo(res.startPosition);
          break;
        case YAxisType.velocity:
          y = state.outerVelocity;
          break;
        case YAxisType.acceleration:
          y = state.outerAcceleration;
          break;
      }

      return y * 100;
    }).toList();
  }

  List<FlSpot> mergeData(final List<double> xValues, final List<double> yValues) => List.generate(
    xValues.length,
        (i) => FlSpot(xValues[i], yValues[i]),
    growable: false,
  );
}

enum XAxisType {
  time("Time"),
  position("Position");

  final String label;
  const XAxisType(this.label);
}

enum YAxisType {
  position("Position"),
  velocity("Velocity"),
  acceleration("Acceleration");

  final String label;
  const YAxisType(this.label);
}