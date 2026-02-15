import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_pilot/file_browser.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/main.dart';

Future<File?> writeBytesToFileWithStatusMessage(
  String path,
  List<int> content, {
  bool showSuccessMessage = true,
  bool showFilePathInMessage = false,
  String? successMessage,
}) async {
  try {
    final file = File(path);
    final f = await compute(file.writeAsBytes, content);
    if (showSuccessMessage) {
      String msg = successMessage ?? "File written successfully";
      if (showFilePathInMessage) {
        msg = "$msg to \"$path\"";
      }
      showSnackBar(msg, duration: const Duration(seconds: 2));
    }
    logger.info("Successfully wrote ${content.length} bytes to $path");
    return f;
  } catch (e, s) {
    logger.errorWithStackTrace("Failed to write ${content.length} bytes to $path", e, s);
    showSnackBar("Failed to write to $path: $e");
    return null;
  }
}

Future<File?> writeStringToFileWithStatusMessage(
  String path,
  String content, {
  bool showFilePathInMessage = false,
  String? successMessage,
  bool showSuccessMessage = true,
}) {
  return writeBytesToFileWithStatusMessage(
    path,
    utf8.encode(content),
    showFilePathInMessage: showFilePathInMessage,
    successMessage: successMessage,
    showSuccessMessage: showSuccessMessage,
  );
}

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

Future<File?> pickFileAndWriteWithStatusMessage({
  required Uint8List bytes,
  required BuildContext context,
  required String extension,
  bool showFilePathInMessage = false,
  String? successMessage,
  bool overwriteWarning = true,
  bool showSuccessMessage = true,
}) async {
  final hasPermission = await getExternalStoragePermission();

  if (!hasPermission) {
    logger.warning("Storage permission not granted, aborting file pick");
    showSnackBar("Please grant storage permission");
    return null;
  }

  if (!extension.startsWith(".")) {
    extension = ".$extension";
  }

  if (!context.mounted) return null;

  String? fileName = await showDialog<String?>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text("Enter file name"),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: "File name", suffix: Text(extension)),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\.\-_]")),
            ],
            validator: (s) {
              if (s == null || s.isEmpty) {
                return "Please enter a file name";
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text);
            },
            child: const Text("Ok"),
          ),
        ],
      );
    },
  );

  if (fileName == null || fileName.isEmpty) return null;

  final directoryPath = await FilePicker.platform.getDirectoryPath();

  if (directoryPath == null) return null;

  final filePath = "$directoryPath/$fileName$extension";

  final file = File(filePath);

  if (overwriteWarning && await file.exists()) {
    if (!context.mounted) return null;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("File already exists"),
          content: const Text("Do you want to overwrite it?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Overwrite"),
            ),
          ],
        );
      },
    );

    if (overwrite == null || !overwrite) return null;
  }

  return writeBytesToFileWithStatusMessage(
    filePath,
    bytes,
    showFilePathInMessage: showFilePathInMessage,
    successMessage: successMessage,
    showSuccessMessage: showSuccessMessage,
  );
}

Directory? lastDirectory;

Future<String?> pickSingleFile({
  String? dialogTitle,
  Directory? initialDirectory,
  List<String>? allowedExtensions,
  required BuildContext context,
}) async {
  if (allowedExtensions != null) {
    for (int i = 0; i < allowedExtensions.length; i++) {
      if (!allowedExtensions[i].startsWith(".")) {
        allowedExtensions[i] = ".${allowedExtensions[i]}";
      }
    }
  }

  initialDirectory ??= lastDirectory;
  lastDirectory = initialDirectory;

  final result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    initialDirectory: initialDirectory?.path,
    allowMultiple: false,
    allowedExtensions: allowedExtensions,
  );

  return result?.files.single.path;
}

Future<Uint8List?> readBytesFromFileWithWithStatusMessage(String path) async {
  try {
    final f = File(path);
    final res = await f.readAsBytes();
    logger.info("Successfully read ${res.length} bytes from $path");
    return res;
  } catch (e, s) {
    logger.errorWithStackTrace("Failed to read from $path", e, s);
    showSnackBar("Failed to read from $path: $e");
    return null;
  }
}

Future<String?> readStringFromFileWithStatusMessage(String path) async {
  final bytes = await readBytesFromFileWithWithStatusMessage(path);
  if (bytes == null) return null;
  return utf8.decode(bytes);
}
