import 'package:flutter/material.dart';

import '../robi_api/robi_utils.dart';
import 'editor.dart';

class AddInstructionDialog extends StatefulWidget {
  final Function(MissionInstruction instruction) instructionAdded;
  final SimulationResult simulationResult;
  final RobiConfig robiConfig;

  const AddInstructionDialog({
    super.key,
    required this.instructionAdded,
    required this.simulationResult,
    required this.robiConfig,
  });

  @override
  State<AddInstructionDialog> createState() => _AddInstructionDialogState();
}

class _AddInstructionDialogState extends State<AddInstructionDialog> {
  UserInstruction selectedInstruction = UserInstruction.drive;

  RadioListTile createRadioButtonForAdd(UserInstruction value) {
    return RadioListTile<UserInstruction>(
      title: ListTile(
        title: Text(value.name),
        leading: Icon(value.icon),
      ),
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Instruction"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final groupName in groupedUserInstructions.keys) ...[
              if (groupedUserInstructions.keys.length > 1) ...[
                Text(groupName, style: const TextStyle(fontSize: 20)),
              ],
              RadioGroup<UserInstruction>(
                groupValue: selectedInstruction,
                onChanged: (value) => setState(() => selectedInstruction = value!),
                child: Column(
                  children: [
                    for (final userInstruction in groupedUserInstructions[groupName]!) ...[
                      createRadioButtonForAdd(userInstruction),
                    ],
                  ],
                ),
              ),
              if (groupName != groupedUserInstructions.keys.last) ...[
                const Divider(height: 5),
              ],
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            final inst = addInstruction(selectedInstruction, widget.robiConfig);
            widget.instructionAdded(inst);
          },
          child: const Text("Ok"),
        ),
      ],
    );
  }
}

enum UserInstruction {
  drive("Drive", Icons.arrow_upward),
  turn("Turn", Icons.turn_right),
  rapidTurn("Rapid Turn", Icons.rotate_right),;

  final String name;
  final IconData icon;

  const UserInstruction(this.name, this.icon);

  factory UserInstruction.fromString(String s) {
    for (final element in UserInstruction.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("Unknown user instruction");
  }
}

MissionInstruction addInstruction(UserInstruction instruction, RobiConfig robiConfig) {
  switch (instruction) {
    case UserInstruction.drive:
      double targetVel = 0.5;
      double acceleration = 0.3;

      return DriveInstruction(
        targetDistance: 1,
        targetVelocity: roundToDigits(targetVel, 2),
        acceleration: acceleration,
        targetFinalVelocity: 0,
      );
    case UserInstruction.turn:
      return TurnInstruction(
        left: true,
        turnDegree: 90,
        innerRadius: 0.5 - robiConfig.trackWidth / 2,
        targetVelocity: 0.3,
        acceleration: 0.1,
        targetFinalVelocity: 0,
      );
    case UserInstruction.rapidTurn:
      return RapidTurnInstruction(
        left: true,
        turnDegree: 90,
        acceleration: 0.1,
        targetVelocity: 0.1,
      );
  }
}

const Map<String, List<UserInstruction>> groupedUserInstructions = {
  "Basic": [UserInstruction.drive, UserInstruction.turn, UserInstruction.rapidTurn],
};
