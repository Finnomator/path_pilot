import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/file_browser.dart';

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';
import '../interactable_visualizer.dart';
import 'approximation_settings_widget.dart';
import 'ir_reading_info.dart';

class IrVisualizerWidget extends StatefulWidget {
  final IrReadResult irReadResult;
  final RobiConfig robiConfig;
  final double time;
  final bool enableTimeInput;
  final SubViewMode subViewMode;
  final List<Obstacle>? obstacles;

  const IrVisualizerWidget({
    super.key,
    required this.robiConfig,
    required this.irReadResult,
    this.time = 0,
    this.enableTimeInput = true,
    required this.subViewMode,
    required this.obstacles,
  });

  @override
  State<IrVisualizerWidget> createState() => _IrVisualizerWidgetState();
}

class _IrVisualizerWidgetState extends State<IrVisualizerWidget> {
  IrReadPainterSettings irReadPainterSettings = IrReadPainterSettings.defaultSettings;
  bool approximatePath = false;

  @override
  Widget build(BuildContext context) {
    final irCalculatorResult = IrCalculator.calculate(widget.irReadResult, widget.robiConfig);

    return StatefulBuilder(builder: (context, setState) {
      InteractableIrVisualizer? visualizer;
      Widget? editor;

      if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.visualizer) {
        visualizer = InteractableIrVisualizer(
          enableTimeInput: widget.enableTimeInput,
          robiConfig: widget.robiConfig,
          totalTime: widget.irReadResult.totalTime,
          irCalculatorResult: irCalculatorResult,
          irPathApproximation: approximatePath
              ? IrCalculator.pathApproximation(
                  irCalculatorResult,
                  irReadPainterSettings.irInclusionThreshold,
                  irReadPainterSettings.ramerDouglasPeuckerTolerance,
                )
              : null,
          irReadPainterSettings: irReadPainterSettings,
          irReadResult: widget.irReadResult,
          obstacles: widget.obstacles,
          onVisibilitySettingsChange: (newSettings) {
            setState(() {
              approximatePath = newSettings.showIrPathApproximation;
            });
          },
        );
      }
      if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.editor) {
        editor = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IrPathApproximationSettingsWidget(
              onSettingsChange: (settings) => setState(() => irReadPainterSettings = settings),
              settings: irReadPainterSettings,
            ),
            const SizedBox(height: 16),
            IrReadingInfoWidget(
              selectedRobiConfig: widget.robiConfig,
              irReadResult: widget.irReadResult,
              irCalculatorResult: irCalculatorResult,
            ),
          ],
        );
      }

      switch (widget.subViewMode) {
        case SubViewMode.editor:
          return editor!;
        case SubViewMode.visualizer:
          return visualizer!;
        case SubViewMode.split:
          final screenSize = MediaQuery.of(context).size;
          final isPortrait = screenSize.width < screenSize.height;
          return ResizableContainer(
            direction: isPortrait ? Axis.vertical : Axis.horizontal,
            children: [
              ResizableChild(child: visualizer!),
              ResizableChild(child: editor!),
            ],
          );
      }
    });
  }
}
