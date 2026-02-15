import 'package:flutter/material.dart';
import 'package:path_pilot/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';

class RapidTurnInstructionEditor extends AbstractEditor {
  @override
  final RapidTurnInstruction instruction;

  RapidTurnInstructionEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
    required super.robiConfig,
    required super.timeChangeNotifier,
    required super.nextInstruction,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    return InstructionCard(
      title: "${instruction.left ? "Left" : "Right"} Rapid Turn ${instruction.turnDegree.round()}°",
      icon: instruction.left ? Icons.rotate_left : Icons.rotate_right,
      warningMessage: warningMessage,
      instruction: instruction,
      instructionResult: instructionResult,
      robiConfig: robiConfig,
      timeChangeNotifier: timeChangeNotifier,
      onRemove: removed,
      onChange: (i) => change(i),
      onEnter: entered,
      onExit: exited,
      customControls: [
        PropertySlider(
          label: "Turn Angle",
          value: instruction.turnDegree,
          unit: "°",
          max: 360.0,
          onChanged: (val) {
            instruction.turnDegree = val.roundToDouble();
            change(instruction);
          },
        ),
        _buildDirectionSwitch(context),
      ],
    );
  }

  Widget _buildDirectionSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text("Direction", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text("Left"), icon: Icon(Icons.turn_left, size: 16)),
              ButtonSegment(value: false, label: Text("Right"), icon: Icon(Icons.turn_right, size: 16)),
            ],
            selected: {instruction.left},
            onSelectionChanged: (Set<bool> newSelection) {
              instruction.left = newSelection.first;
              change(instruction);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}