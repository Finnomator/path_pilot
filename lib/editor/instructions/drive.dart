import 'package:flutter/material.dart';
import 'package:path_pilot/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class DriveInstructionEditor extends AbstractEditor {
  @override
  final DriveInstruction instruction;

  DriveInstructionEditor({
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
      title: "Drive ${(instruction.targetDistance * 100).round()}cm",
      icon: Icons.straight, // Assuming UserInstruction.drive.icon is a straight arrow
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
          label: "Distance",
          value: instruction.targetDistance,
          unit: "cm",
          max: 5.0,
          scaleFactor: 100,
          onChanged: (val) {
            instruction.targetDistance = roundToDigits(val, 3);
            change(instruction);
          },
        ),
      ],
    );
  }
}