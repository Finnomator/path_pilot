import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/editor/instructions/instruction_details.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

import '../painters/robi_painter.dart'; // Assumed location

/// Base class for all instruction editors.
/// Handles common logic for warnings, state updates, and data passing.
abstract class AbstractEditor extends StatelessWidget {
  final SimulationResult simulationResult;
  final int instructionIndex;
  final MissionInstruction instruction;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;
  final MissionInstruction? nextInstruction;

  late final InstructionResult instructionResult;
  late final bool isLastInstruction;

  final Function(MissionInstruction newInstruction) change;
  final Function() removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;

  late final String? warningMessage = _generateWarning();
  final String? _warning;

  AbstractEditor({
    super.key,
    required this.simulationResult,
    required this.instructionIndex,
    required this.change,
    required this.removed,
    required this.instruction,
    required this.robiConfig,
    required this.nextInstruction,
    String? warning,
    this.entered,
    this.exited,
    required this.timeChangeNotifier,
  }) : _warning = warning {
    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction = instructionIndex == simulationResult.instructionResults.length - 1;
  }

  String? _generateWarning() {
    if (_warning != null) return _warning;

    if (isLastInstruction && instructionResult.highestFinalVelocity.abs() > floatTolerance) {
      return "Robi will not stop at the end";
    }
    if ((instructionResult.highestMaxVelocity - instruction.targetVelocity).abs() > floatTolerance) {
      return "Robi will only reach ${roundToDigits(instructionResult.highestMaxVelocity * 100, 2)}cm/s";
    }
    if (instructionResult.highestMaxVelocity > robiConfig.maxVelocity) {
      return "Robi will exceed the maximum velocity";
    }
    if (instructionResult.maxAcceleration > robiConfig.maxAcceleration) {
      return "Robi will exceed the maximum acceleration";
    }
    if (nextInstruction != null && instructionResult.highestFinalVelocity > nextInstruction!.targetVelocity + floatTolerance) {
      return "Robi's final velocity must be <= ${roundToDigits(nextInstruction!.targetVelocity * 100, 2)}cm/s";
    }
    return null;
  }
}

/// A standardized card widget for editing instructions.
/// Includes header, warnings, common motion profile controls, and expansion logic.
class InstructionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? warningMessage;

  final MissionInstruction instruction;
  final InstructionResult instructionResult;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;

  final VoidCallback onRemove;
  final Function(MissionInstruction) onChange;
  final Function(InstructionResult)? onEnter;
  final VoidCallback? onExit;

  final List<Widget> customControls;

  const InstructionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.instruction,
    required this.instructionResult,
    required this.robiConfig,
    required this.timeChangeNotifier,
    required this.onRemove,
    required this.onChange,
    this.warningMessage,
    this.onEnter,
    this.onExit,
    this.customControls = const [],
  });

  @override
  State<InstructionCard> createState() => _InstructionCardState();
}

class _InstructionCardState extends State<InstructionCard> {
  bool isExpanded = false;

  double get progress {
    if (widget.instructionResult.totalTime == 0) return 0;
    return (widget.timeChangeNotifier.time - widget.instructionResult.timeStamp) / widget.instructionResult.totalTime;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasWarning = widget.warningMessage != null;

    return MouseRegion(
      onEnter: (_) => widget.onEnter?.call(widget.instructionResult),
      onExit: (_) => widget.onExit?.call(),
      child: Card(
        elevation: isExpanded ? 4 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hasWarning ? BorderSide(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Progress Indicator
            ListenableBuilder(
              listenable: widget.timeChangeNotifier,
              builder: (context, _) => LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: colorScheme.primary,
              ),
            ),

            // Header & Expansion
            ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (v) => setState(() => isExpanded = v),
              tilePadding: const EdgeInsets.fromLTRB(16, 4, 40, 4),
              shape: const Border(), // Remove default borders
              collapsedShape: const Border(),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              title: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasWarning)
                    Tooltip(
                      message: widget.warningMessage,
                      child: IconButton(
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        onPressed: () => _showWarningDialog(context),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                    onPressed: widget.onRemove,
                    tooltip: "Remove Instruction",
                  ),
                ],
              ),
              children: [
                const Divider(height: 1),
                _buildEditorBody(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Controls (Specific to the instruction type)
          if (widget.customControls.isNotEmpty) ...[
            Text("PARAMETERS", style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            ...widget.customControls,
            const SizedBox(height: 24),
          ],

          // Common Motion Profile Controls
          Text("MOTION PROFILE", style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          PropertySlider(
            label: "Max Acceleration",
            value: widget.instruction.acceleration,
            unit: "cm/s²",
            max: widget.robiConfig.maxAcceleration,
            scaleFactor: 100, // Display as cm/s² but store as m/s² if needed (based on previous code logic)
            onChanged: (val) {
              widget.instruction.acceleration = roundToDigits(val, 3);
              widget.onChange(widget.instruction);
            },
          ),
          PropertySlider(
            label: "Target Velocity",
            value: widget.instruction.targetVelocity,
            unit: "cm/s",
            max: widget.robiConfig.maxVelocity,
            min: 0.001,
            scaleFactor: 100,
            onChanged: (val) {
              widget.instruction.targetVelocity = roundToDigits(val, 3);
              widget.onChange(widget.instruction);
            },
          ),

          const SizedBox(height: 24),

          // Charts/Details
          if (widget.instructionResult.totalTime > 0)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.all(16),
              child: InstructionDetailsWidget(
                instructionResult: widget.instructionResult,
                robiConfig: widget.robiConfig,
                timeChangeNotifier: widget.timeChangeNotifier,
              ),
            ),
        ],
      ),
    );
  }

  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: const [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text("Simulation Warning")]),
        content: Text(widget.warningMessage ?? ""),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Dismiss")),
        ],
      ),
    );
  }
}

/// A reusable slider widget with a label and value readout.
class PropertySlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String unit;
  final double scaleFactor; // Multiplier for display (e.g. 0.01m -> 1cm)

  const PropertySlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    required this.max,
    this.unit = "",
    this.scaleFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp value for the slider visual, but keep actual value logic in onChanged
    final sliderValue = value.clamp(min, max);
    final displayValue = value * scaleFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${roundToDigits(displayValue, 2)}$unit",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 30,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: sliderValue,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}