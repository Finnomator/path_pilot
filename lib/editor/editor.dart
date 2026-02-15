import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:path_pilot/editor/add_instruction_dialog.dart';
import 'package:path_pilot/editor/instructions/abstract.dart';
import 'package:path_pilot/editor/instructions/rapid_turn.dart';
import 'package:path_pilot/editor/interactable_visualizer.dart';
import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/file_browser.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

import '../app_storage.dart';
import '../robi_api/simulator.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';

final inputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'^(\d+)?\.?\d{0,5}'))];

class Editor extends StatefulWidget {
  final List<MissionInstruction> initialInstructions;
  final RobiConfig selectedRobiConfig;
  final SubViewMode subViewMode;
  final void Function(List<MissionInstruction> newInstructions, SimulationResult newSimulationResult) onInstructionsChanged;
  final void Function(SimulationResult result) firstSimulationResult;
  final List<Obstacle>? obstacles;

  const Editor({
    super.key,
    required this.initialInstructions,
    required this.selectedRobiConfig,
    required this.subViewMode,
    required this.onInstructionsChanged,
    required this.obstacles,
    required this.firstSimulationResult,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with AutomaticKeepAliveClientMixin {
  late List<MissionInstruction> instructions = List.from(widget.initialInstructions);
  late Simulator simulator = Simulator(widget.selectedRobiConfig);

  // Visualizer
  final timeNotifier = TimeChangeNotifier();
  InstructionResult? highlightedInstruction;
  late SimulationResult simulationResult = simulator.calculate(instructions);

  // Developer Options
  int randomInstructionsGenerationLength = 100;
  Duration? randomInstructionsGenerationDuration;

  @override
  void initState() {
    super.initState();
    widget.firstSimulationResult(simulationResult);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    InteractableInstructionsVisualizer? visualizer;
    Widget? editor;

    if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.visualizer) {
      visualizer = InteractableInstructionsVisualizer(
        simulationResult: simulationResult,
        totalTime: simulationResult.totalTime,
        robiConfig: widget.selectedRobiConfig,
        highlightedInstruction: highlightedInstruction,
        onTimeChanged: (newTime) => timeNotifier.time = newTime,
        obstacles: widget.obstacles,
      );
    }

    if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.editor) {
      editor = Stack(
        children: [
          instructions.isEmpty
              ? const Center(
                  child: Text("Add a first instruction to begin"),
                )
              : ReorderableListView.builder(
                  header: const SizedBox(height: 3),
                  itemCount: instructions.length,
                  itemBuilder: (context, i) => instructionToEditor(i),
                  onReorder: (int oldIndex, int newIndex) {
                    if (oldIndex < newIndex) --newIndex;
                    instructions.insert(newIndex, instructions.removeAt(oldIndex));
                    rerunSimulationAndUpdate();
                  },
                  footer: const SizedBox(height: 200),
                ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Card.outlined(
                          child: IconButton(
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (BuildContext context) => AddInstructionDialog(
                                instructionAdded: (MissionInstruction instruction) {
                                  instructions.insert(instructions.length, instruction);
                                  rerunSimulationAndUpdate();
                                },
                                robiConfig: widget.selectedRobiConfig,
                                simulationResult: simulationResult,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Card.outlined(
                        child: IconButton(
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          onPressed: () async {
                            if (!await confirmDialog(context, "Confirm Deletion", "Are you sure you want to delete all instructions?")) return;
                            timeNotifier.time = 0;
                            instructions.clear();
                            rerunSimulationAndUpdate();
                          },
                          icon: const Icon(Icons.delete_forever),
                        ),
                      ),
                    ],
                  ),
                  if (SettingsStorage.developerMode) ...[
                    Card.outlined(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            const Text("Generate Random Instructions"),
                            Row(
                              children: [
                                Flexible(
                                  child: TextFormField(
                                    initialValue: randomInstructionsGenerationLength.toString(),
                                    onChanged: (value) {
                                      final parsed = int.tryParse(value);
                                      if (parsed == null) return;
                                      randomInstructionsGenerationLength = parsed;
                                    },
                                    decoration: const InputDecoration(labelText: "Generation Length"),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (randomInstructionsGenerationDuration != null) Text("(took ${randomInstructionsGenerationDuration!.inMilliseconds}ms)"),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () {
                                    for (int i = 0; i < randomInstructionsGenerationLength; i++) {
                                      instructions.add(MissionInstruction.generateRandom(widget.selectedRobiConfig));
                                    }
                                    final sw = Stopwatch()..start();
                                    rerunSimulationAndUpdate();
                                    sw.stop();
                                    setState(() {
                                      randomInstructionsGenerationDuration = sw.elapsed;
                                    });
                                  },
                                  icon: const Icon(Icons.send),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
  }

  void enteredCallback(InstructionResult instructionResult) {
    setState(() {
      highlightedInstruction = instructionResult;
    });
  }

  void exitedCallback() {
    setState(() {
      highlightedInstruction = null;
    });
  }

  AbstractEditor instructionToEditor(int i) {
    final instruction = instructions[i];
    final nextInstruction = instructions.elementAtOrNull(i + 1);

    void changeCallback(MissionInstruction newInstruction) {
      instructions[i] = newInstruction;
      rerunSimulationAndUpdate();
    }

    void removedCallback() {
      instructions.removeAt(i);
      rerunSimulationAndUpdate();
    }

    if (instruction is DriveInstruction) {
      return DriveInstructionEditor(
        timeChangeNotifier: timeNotifier,
        robiConfig: widget.selectedRobiConfig,
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        exited: exitedCallback,
        entered: enteredCallback,
        nextInstruction: nextInstruction,
      );
    } else if (instruction is TurnInstruction) {
      return TurnInstructionEditor(
        timeChangeNotifier: timeNotifier,
        robiConfig: widget.selectedRobiConfig,
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        exited: exitedCallback,
        entered: enteredCallback,
        nextInstruction: nextInstruction,
      );
    } else if (instruction is RapidTurnInstruction) {
      return RapidTurnInstructionEditor(
        timeChangeNotifier: timeNotifier,
        robiConfig: widget.selectedRobiConfig,
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        exited: exitedCallback,
        entered: enteredCallback,
        nextInstruction: nextInstruction,
      );
    }
    throw UnsupportedError("");
  }

  void rerunSimulationAndUpdate() {
    InstructionResult? currentResult;

    for (int i = 0; i < instructions.length - 1; ++i) {
      final instruction = instructions[i];
      final nextInstruction = instructions[i + 1];

      if (nextInstruction is RapidTurnInstruction) {
        // Always stop at end of instruction if next instruction is rapid turn.
        instruction.targetFinalVelocity = 0;
      } else {
        if (instruction.targetVelocity > nextInstruction.targetVelocity) {
          // Ensure the initial velocity for the next instruction is always <= than the target velocity.
          instruction.targetFinalVelocity = nextInstruction.targetVelocity;
        } else {
          instruction.targetFinalVelocity = instruction.targetVelocity;
        }
      }

      if (currentResult != null) {
        // Ensure the initial velocity for the next instruction is always <= than the target velocity
        // because an instruction cannot decelerate to target velocity, only accelerate.
        if (currentResult.highestFinalVelocity > nextInstruction.targetVelocity) {
          instruction.acceleration = widget.selectedRobiConfig.maxAcceleration;
        }
      }

      currentResult = simulator.simulateInstruction(currentResult, instruction);
    }

    // Always decelerate to stop at end
    instructions.lastOrNull?.targetFinalVelocity = 0;

    setState(() {
      simulationResult = simulator.calculate(instructions);
    });
    timeNotifier.time = timeNotifier.time.clamp(0, simulationResult.totalTime);

    widget.onInstructionsChanged(instructions, simulationResult);
  }

  @override
  bool get wantKeepAlive => true;
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}

class TimeChangeNotifier extends ChangeNotifier {
  double _time = 0;

  double get time => _time;

  set time(double newTime) {
    _time = newTime;
    notifyListeners();
  }
}
