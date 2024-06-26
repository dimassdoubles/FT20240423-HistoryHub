import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:history_hub/src/core/helper/dialog_helper.dart';
import 'package:history_hub/src/core/router/app_router.gr.dart';
import 'package:history_hub/src/core/constants/styles/app_colors.dart';
import 'package:history_hub/src/core/constants/styles/common_sizes.dart';
import 'package:history_hub/src/features/photo_editor/presentation/widgets/action_button.dart';
import 'package:history_hub/src/features/photo_editor/presentation/widgets/color_slider.dart';
import 'package:history_hub/src/features/photo_editor/presentation/widgets/line_weight_selector.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_sketcher/image_sketcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class PhotoEditorScreen extends HookConsumerWidget {
  final File rawImage;
  final void Function(File image)? onImageSelected;
  const PhotoEditorScreen({
    super.key,
    required this.rawImage,
    this.onImageSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useImageKey = useState(GlobalKey<ImageSketcherState>());
    final useKey = useState(GlobalKey<ScaffoldState>());

    final useDrawColor = useState(Colors.white);
    final usePaintMode = useState(PaintMode.none);
    final useIsEditText = useState(false);

    final useScreenshotCtrl = useState(ScreenshotController());

    return Material(
      key: useKey.value,
      color: AppColors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Screenshot(
              controller: useScreenshotCtrl.value,
              child: ImageSketcher.file(
                rawImage,
                key: useImageKey.value,
                enableToolbar: false,
                initialPaintMode: usePaintMode.value,
                initialColor: useDrawColor.value,
              ),
            ),

            // default bottom bar
            if (usePaintMode.value != PaintMode.freeStyle &&
                !useIsEditText.value)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(CommonSizes.pagePadding),
                  child: ActionButton(
                    onTap: () {
                      saveImage(
                        context,
                        useScreenshotCtrl.value,
                      );
                    },
                    icon: Icons.done_rounded,
                    backgroundColor: AppColors.primary500,
                  ),
                ),
              ),

            // text bottom bar
            if (useIsEditText.value)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Text("Hello World"),
              ),

            // draw bottom bar
            if (usePaintMode.value == PaintMode.freeStyle)
              Align(
                alignment: Alignment.bottomCenter,
                child: LineWeightSelector(
                  onBrushWeightChanged: (weight) {
                    useImageKey.value.currentState?.changeBrushWidth(weight);
                  },
                ),
              ),

            // default top bar
            if (!useIsEditText.value &&
                usePaintMode.value != PaintMode.freeStyle)
              _DefaultTopBar(
                onCancelTap: () => context.maybePop(),
                onEnterDrawMode: () {
                  useImageKey.value.currentState
                      ?.changePaintMode(PaintMode.freeStyle);
                  usePaintMode.value = PaintMode.freeStyle;
                },
                onEnterTextMode: () {
                  useImageKey.value.currentState
                      ?.changePaintMode(PaintMode.text);
                  usePaintMode.value = PaintMode.text;
                  useIsEditText.value = true;
                },
                onUndoTap: () {
                  useImageKey.value.currentState?.undo();
                },
              ),

            // text top bar
            if (useIsEditText.value)
              _TextTopBar(
                initialColor: useDrawColor.value,
                onDone: (text) {
                  useImageKey.value.currentState?.addText(text);
                  useIsEditText.value = false;
                },
                onColorChanged: (newColor) {
                  useDrawColor.value = newColor;
                  useImageKey.value.currentState?.updateColor(newColor);
                },
              ),

            // draw top bar
            if (usePaintMode.value == PaintMode.freeStyle)
              _DrawTopBar(
                initialColor: useDrawColor.value,
                onColorChanged: (selectedColor) {
                  useImageKey.value.currentState?.updateColor(selectedColor);
                  useDrawColor.value = selectedColor;
                },
                onUndo: () {
                  useImageKey.value.currentState?.undo();
                },
                onDone: () {
                  useImageKey.value.currentState
                      ?.changePaintMode(PaintMode.none);
                  usePaintMode.value = PaintMode.none;
                },
              ),
          ],
        ),
      ),
    );
  }

  void saveImage(
    BuildContext context,
    ScreenshotController controller,
  ) async {
    DialogHelper.showLoading();
    bool isLoading = true;

    try {
      final tempDir = await getTemporaryDirectory();
      String fileName =
          '${DateTime.now().microsecondsSinceEpoch.toString()}.png';

      final image = await controller.captureAndSave(
        tempDir.path,
        fileName: fileName,
      );

      if (image != null) {
        onImageSelected?.call(File(image));
        DialogHelper.dismiss();
        isLoading = false;
      }
    } catch (e) {
      if (isLoading) DialogHelper.dismiss();
      debugPrint("saveImage error: $e");
    } finally {
      // ignore: use_build_context_synchronously
      context.router.popUntil(
        (route) => route.settings.name == CreatePostRoute.name,
      );
    }
  }
}

class _TextTopBar extends StatefulWidget {
  final Color _initialColor;
  final void Function(String text)? _onDone;
  final void Function(Color color)? _onColorChanged;
  const _TextTopBar({
    required Color initialColor,
    void Function(String text)? onDone,
    void Function(Color color)? onColorChanged,
  })  : _onDone = onDone,
        _onColorChanged = onColorChanged,
        _initialColor = initialColor;

  @override
  State<_TextTopBar> createState() => _TextTopBarState();
}

class _TextTopBarState extends State<_TextTopBar> {
  final FocusNode _textFocus = FocusNode();
  final TextEditingController _textController = TextEditingController();

  late Color color = widget._initialColor;

  @override
  void initState() {
    _textFocus.requestFocus();
    debugPrint("requestFocus");
    super.initState();
  }

  @override
  void dispose() {
    _textFocus.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    widget._onDone?.call(_textController.text);
                  },
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: ColorSlider(
                    onColorChanged: (selectedColor) {
                      setState(() {
                        color = selectedColor;
                      });
                      widget._onColorChanged?.call(selectedColor);
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: TextField(
                focusNode: _textFocus,
                controller: _textController,
                onSubmitted: (value) => widget._onDone?.call(value),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Add text",
                  hintStyle: TextStyle(
                    fontSize: 24,
                    color: color.withOpacity(0.5),
                  ),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawTopBar extends StatefulWidget {
  final Color _initialColor;
  final void Function(Color selectedColor)? _onColorChanged;
  final void Function()? _onDone;
  final void Function()? _onUndo;
  const _DrawTopBar({
    required Color initialColor,
    Function(Color selectedColor)? onColorChanged,
    void Function()? onDone,
    void Function()? onUndo,
  })  : _initialColor = initialColor,
        _onColorChanged = onColorChanged,
        _onDone = onDone,
        _onUndo = onUndo;

  @override
  State<_DrawTopBar> createState() => _DrawTopBarState();
}

class _DrawTopBarState extends State<_DrawTopBar> {
  late Color color = widget._initialColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          GestureDetector(
            onTap: widget._onDone,
            child: const Text(
              "Done",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ActionButton(
                  onTap: widget._onUndo,
                  icon: Icons.undo,
                ),
                const SizedBox(
                  width: 16,
                ),
                Column(
                  children: [
                    ActionButton(
                      onTap: () {},
                      icon: Icons.edit_outlined,
                      backgroundColor: color,
                      color: color == Colors.white
                          ? AppColors.black
                          : Colors.white,
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    ColorSlider(
                      onColorChanged: (selectedColor) {
                        setState(() {
                          color = selectedColor;
                        });
                        widget._onColorChanged?.call(selectedColor);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultTopBar extends StatelessWidget {
  final void Function()? _onCancelTap;
  final void Function()? _onUndoTap;
  final void Function()? _onEnterTextMode;
  final void Function()? _onEnterDrawMode;
  const _DefaultTopBar({
    void Function()? onCancelTap,
    void Function()? onUndoTap,
    void Function()? onEnterTextMode,
    void Function()? onEnterDrawMode,
  })  : _onCancelTap = onCancelTap,
        _onUndoTap = onUndoTap,
        _onEnterTextMode = onEnterTextMode,
        _onEnterDrawMode = onEnterDrawMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          ActionButton(
            onTap: _onCancelTap,
            icon: Icons.clear,
          ),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ActionButton(
                  onTap: _onUndoTap,
                  icon: Icons.undo,
                ),
                const SizedBox(
                  width: 16,
                ),
                ActionButton(
                  onTap: _onEnterTextMode,
                  icon: Icons.text_fields_outlined,
                ),
                const SizedBox(
                  width: 16,
                ),
                ActionButton(
                  onTap: () {
                    debugPrint("Aksi draw di klik");
                    _onEnterDrawMode?.call();
                  },
                  icon: Icons.edit_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
