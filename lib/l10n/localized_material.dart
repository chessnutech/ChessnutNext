export 'package:flutter/material.dart'
    hide
        DropdownButtonFormField,
        IconButton,
        Text,
        TextField,
        TextFormField,
        Tooltip;

import 'dart:ui' as ui show TextHeightBehavior;

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show TextInputFormatter;

import 'app_strings.dart';

class Text extends material.StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    material.InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;

  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  final double? textScaleFactor;
  material.TextScaler? get _effectiveTextScaler {
    if (textScaler != null) return textScaler;
    final scaleFactor = textScaleFactor;
    return scaleFactor == null ? null : material.TextScaler.linear(scaleFactor);
  }

  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    final source = data;
    if (source != null) {
      final translated = AppStrings.maybeOf(context)?.t(source) ?? source;
      return material.Text(
        translated,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: _effectiveTextScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null
            ? null
            : AppStrings.maybeOf(context)?.t(semanticsLabel!) ?? semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return material.Text.rich(
      textSpan!,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: _effectiveTextScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : AppStrings.maybeOf(context)?.t(semanticsLabel!) ?? semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class TextField extends material.StatelessWidget {
  const TextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const material.InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = material.TextCapitalization.none,
    this.style,
    this.textAlign = material.TextAlign.start,
    this.textAlignVertical,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const material.EdgeInsets.all(20),
    this.enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.mouseCursor,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.restorationId,
    this.canRequestFocus = true,
  });

  final material.TextEditingController? controller;
  final material.FocusNode? focusNode;
  final material.InputDecoration? decoration;
  final material.TextInputType? keyboardType;
  final material.TextInputAction? textInputAction;
  final material.TextCapitalization textCapitalization;
  final material.TextStyle? style;
  final material.TextAlign textAlign;
  final material.TextAlignVertical? textAlignVertical;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final String obscuringCharacter;
  final bool obscureText;
  final bool? autocorrect;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final material.ValueChanged<String>? onChanged;
  final material.VoidCallback? onEditingComplete;
  final material.ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final material.Radius? cursorRadius;
  final material.Color? cursorColor;
  final material.Brightness? keyboardAppearance;
  final material.EdgeInsets scrollPadding;
  final bool? enableInteractiveSelection;
  final material.TextSelectionControls? selectionControls;
  final material.GestureTapCallback? onTap;
  final material.MouseCursor? mouseCursor;
  final material.ScrollController? scrollController;
  final material.ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final String? restorationId;
  final bool canRequestFocus;

  @override
  material.Widget build(material.BuildContext context) {
    return material.TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: _localizedDecoration(context, decoration),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      readOnly: readOnly,
      showCursor: showCursor,
      autofocus: autofocus,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: cursorColor,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding,
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      onTap: onTap,
      mouseCursor: mouseCursor,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      restorationId: restorationId,
      canRequestFocus: canRequestFocus,
    );
  }
}

class TextFormField extends material.StatelessWidget {
  const TextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration = const material.InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = material.TextCapitalization.none,
    this.style,
    this.textAlign = material.TextAlign.start,
    this.textAlignVertical,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const material.EdgeInsets.all(20),
    this.enableInteractiveSelection,
    this.selectionControls,
    this.scrollPhysics,
    this.autofillHints,
    this.autovalidateMode,
    this.scrollController,
    this.restorationId,
    this.mouseCursor,
    this.canRequestFocus = true,
  });

  final material.TextEditingController? controller;
  final String? initialValue;
  final material.FocusNode? focusNode;
  final material.InputDecoration? decoration;
  final material.TextInputType? keyboardType;
  final material.TextInputAction? textInputAction;
  final material.TextCapitalization textCapitalization;
  final material.TextStyle? style;
  final material.TextAlign textAlign;
  final material.TextAlignVertical? textAlignVertical;
  final bool autofocus;
  final bool readOnly;
  final bool? showCursor;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final material.ValueChanged<String>? onChanged;
  final material.GestureTapCallback? onTap;
  final material.VoidCallback? onEditingComplete;
  final material.ValueChanged<String>? onFieldSubmitted;
  final material.FormFieldSetter<String>? onSaved;
  final material.FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final material.Radius? cursorRadius;
  final material.Color? cursorColor;
  final material.Brightness? keyboardAppearance;
  final material.EdgeInsets scrollPadding;
  final bool? enableInteractiveSelection;
  final material.TextSelectionControls? selectionControls;
  final material.ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final material.AutovalidateMode? autovalidateMode;
  final material.ScrollController? scrollController;
  final String? restorationId;
  final material.MouseCursor? mouseCursor;
  final bool canRequestFocus;

  @override
  material.Widget build(material.BuildContext context) {
    return material.TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: _localizedDecoration(context, decoration),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      autofocus: autofocus,
      readOnly: readOnly,
      showCursor: showCursor,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      inputFormatters: inputFormatters,
      enabled: enabled,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: cursorColor,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding,
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      autovalidateMode: autovalidateMode,
      scrollController: scrollController,
      restorationId: restorationId,
      mouseCursor: mouseCursor,
      canRequestFocus: canRequestFocus,
    );
  }
}

class DropdownButtonFormField<T> extends material.StatelessWidget {
  const DropdownButtonFormField({
    super.key,
    required this.items,
    this.selectedItemBuilder,
    this.value,
    this.initialValue,
    this.hint,
    this.disabledHint,
    required this.onChanged,
    this.onTap,
    this.elevation = 8,
    this.style,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24,
    this.isDense = true,
    this.isExpanded = false,
    this.itemHeight,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.decoration,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
    this.menuMaxHeight,
    this.enableFeedback,
    this.alignment = material.AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.barrierDismissible = true,
  });

  final List<material.DropdownMenuItem<T>>? items;
  final material.DropdownButtonBuilder? selectedItemBuilder;
  final T? value;
  final T? initialValue;
  final material.Widget? hint;
  final material.Widget? disabledHint;
  final material.ValueChanged<T?>? onChanged;
  final material.VoidCallback? onTap;
  final int elevation;
  final material.TextStyle? style;
  final material.Widget? icon;
  final material.Color? iconDisabledColor;
  final material.Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final material.Color? focusColor;
  final material.FocusNode? focusNode;
  final bool autofocus;
  final material.Color? dropdownColor;
  final material.InputDecoration? decoration;
  final material.FormFieldSetter<T>? onSaved;
  final material.FormFieldValidator<T>? validator;
  final material.AutovalidateMode? autovalidateMode;
  final double? menuMaxHeight;
  final bool? enableFeedback;
  final material.AlignmentGeometry alignment;
  final material.BorderRadius? borderRadius;
  final material.EdgeInsetsGeometry? padding;
  final bool barrierDismissible;

  @override
  material.Widget build(material.BuildContext context) {
    return material.DropdownButtonFormField<T>(
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      // ignore: deprecated_member_use
      value: value,
      initialValue: initialValue,
      hint: hint,
      disabledHint: disabledHint,
      onChanged: onChanged,
      onTap: onTap,
      elevation: elevation,
      style: style,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      isDense: isDense,
      isExpanded: isExpanded,
      itemHeight: itemHeight,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      dropdownColor: dropdownColor,
      decoration: _localizedDecoration(context, decoration),
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
      menuMaxHeight: menuMaxHeight,
      enableFeedback: enableFeedback,
      alignment: alignment,
      borderRadius: borderRadius,
      padding: padding,
      barrierDismissible: barrierDismissible,
    );
  }
}

enum _IconButtonVariant { standard, filled, filledTonal, outlined }

class IconButton extends material.StatelessWidget {
  const IconButton({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    required this.onPressed,
    this.onHover,
    this.onLongPress,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.enableFeedback,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.statesController,
    required this.icon,
  }) : _variant = _IconButtonVariant.standard;

  const IconButton.filled({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    required this.onPressed,
    this.onHover,
    this.onLongPress,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.enableFeedback,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.statesController,
    required this.icon,
  }) : _variant = _IconButtonVariant.filled;

  const IconButton.filledTonal({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    required this.onPressed,
    this.onHover,
    this.onLongPress,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.enableFeedback,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.statesController,
    required this.icon,
  }) : _variant = _IconButtonVariant.filledTonal;

  const IconButton.outlined({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    required this.onPressed,
    this.onHover,
    this.onLongPress,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.enableFeedback,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.statesController,
    required this.icon,
  }) : _variant = _IconButtonVariant.outlined;

  final _IconButtonVariant _variant;
  final double? iconSize;
  final material.VisualDensity? visualDensity;
  final material.EdgeInsetsGeometry? padding;
  final material.AlignmentGeometry? alignment;
  final double? splashRadius;
  final material.Color? color;
  final material.Color? focusColor;
  final material.Color? hoverColor;
  final material.Color? highlightColor;
  final material.Color? splashColor;
  final material.Color? disabledColor;
  final material.VoidCallback? onPressed;
  final material.ValueChanged<bool>? onHover;
  final material.VoidCallback? onLongPress;
  final material.MouseCursor? mouseCursor;
  final material.FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final bool? enableFeedback;
  final material.BoxConstraints? constraints;
  final material.ButtonStyle? style;
  final bool? isSelected;
  final material.Widget? selectedIcon;
  final material.WidgetStatesController? statesController;
  final material.Widget icon;

  @override
  material.Widget build(material.BuildContext context) {
    final localizedTooltip = _localizedText(context, tooltip);
    final args = _IconButtonArgs(
      iconSize: iconSize,
      visualDensity: visualDensity,
      padding: padding,
      alignment: alignment,
      splashRadius: splashRadius,
      color: color,
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      splashColor: splashColor,
      disabledColor: disabledColor,
      onPressed: onPressed,
      onHover: onHover,
      onLongPress: onLongPress,
      mouseCursor: mouseCursor,
      focusNode: focusNode,
      autofocus: autofocus,
      tooltip: localizedTooltip,
      enableFeedback: enableFeedback,
      constraints: constraints,
      style: style,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      statesController: statesController,
      icon: icon,
    );
    return switch (_variant) {
      _IconButtonVariant.standard => material.IconButton(
          iconSize: args.iconSize,
          visualDensity: args.visualDensity,
          padding: args.padding,
          alignment: args.alignment,
          splashRadius: args.splashRadius,
          color: args.color,
          focusColor: args.focusColor,
          hoverColor: args.hoverColor,
          highlightColor: args.highlightColor,
          splashColor: args.splashColor,
          disabledColor: args.disabledColor,
          onPressed: args.onPressed,
          onHover: args.onHover,
          onLongPress: args.onLongPress,
          mouseCursor: args.mouseCursor,
          focusNode: args.focusNode,
          autofocus: args.autofocus,
          tooltip: args.tooltip,
          enableFeedback: args.enableFeedback,
          constraints: args.constraints,
          style: args.style,
          isSelected: args.isSelected,
          selectedIcon: args.selectedIcon,
          statesController: args.statesController,
          icon: args.icon,
        ),
      _IconButtonVariant.filled => material.IconButton.filled(
          iconSize: args.iconSize,
          visualDensity: args.visualDensity,
          padding: args.padding,
          alignment: args.alignment,
          splashRadius: args.splashRadius,
          color: args.color,
          focusColor: args.focusColor,
          hoverColor: args.hoverColor,
          highlightColor: args.highlightColor,
          splashColor: args.splashColor,
          disabledColor: args.disabledColor,
          onPressed: args.onPressed,
          onHover: args.onHover,
          onLongPress: args.onLongPress,
          mouseCursor: args.mouseCursor,
          focusNode: args.focusNode,
          autofocus: args.autofocus,
          tooltip: args.tooltip,
          enableFeedback: args.enableFeedback,
          constraints: args.constraints,
          style: args.style,
          isSelected: args.isSelected,
          selectedIcon: args.selectedIcon,
          statesController: args.statesController,
          icon: args.icon,
        ),
      _IconButtonVariant.filledTonal => material.IconButton.filledTonal(
          iconSize: args.iconSize,
          visualDensity: args.visualDensity,
          padding: args.padding,
          alignment: args.alignment,
          splashRadius: args.splashRadius,
          color: args.color,
          focusColor: args.focusColor,
          hoverColor: args.hoverColor,
          highlightColor: args.highlightColor,
          splashColor: args.splashColor,
          disabledColor: args.disabledColor,
          onPressed: args.onPressed,
          onHover: args.onHover,
          onLongPress: args.onLongPress,
          mouseCursor: args.mouseCursor,
          focusNode: args.focusNode,
          autofocus: args.autofocus,
          tooltip: args.tooltip,
          enableFeedback: args.enableFeedback,
          constraints: args.constraints,
          style: args.style,
          isSelected: args.isSelected,
          selectedIcon: args.selectedIcon,
          statesController: args.statesController,
          icon: args.icon,
        ),
      _IconButtonVariant.outlined => material.IconButton.outlined(
          iconSize: args.iconSize,
          visualDensity: args.visualDensity,
          padding: args.padding,
          alignment: args.alignment,
          splashRadius: args.splashRadius,
          color: args.color,
          focusColor: args.focusColor,
          hoverColor: args.hoverColor,
          highlightColor: args.highlightColor,
          splashColor: args.splashColor,
          disabledColor: args.disabledColor,
          onPressed: args.onPressed,
          onHover: args.onHover,
          onLongPress: args.onLongPress,
          mouseCursor: args.mouseCursor,
          focusNode: args.focusNode,
          autofocus: args.autofocus,
          tooltip: args.tooltip,
          enableFeedback: args.enableFeedback,
          constraints: args.constraints,
          style: args.style,
          isSelected: args.isSelected,
          selectedIcon: args.selectedIcon,
          statesController: args.statesController,
          icon: args.icon,
        ),
    };
  }
}

class _IconButtonArgs {
  const _IconButtonArgs({
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.alignment,
    this.splashRadius,
    this.color,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.disabledColor,
    required this.onPressed,
    this.onHover,
    this.onLongPress,
    this.mouseCursor,
    this.focusNode,
    required this.autofocus,
    this.tooltip,
    this.enableFeedback,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    this.statesController,
    required this.icon,
  });

  final double? iconSize;
  final material.VisualDensity? visualDensity;
  final material.EdgeInsetsGeometry? padding;
  final material.AlignmentGeometry? alignment;
  final double? splashRadius;
  final material.Color? color;
  final material.Color? focusColor;
  final material.Color? hoverColor;
  final material.Color? highlightColor;
  final material.Color? splashColor;
  final material.Color? disabledColor;
  final material.VoidCallback? onPressed;
  final material.ValueChanged<bool>? onHover;
  final material.VoidCallback? onLongPress;
  final material.MouseCursor? mouseCursor;
  final material.FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final bool? enableFeedback;
  final material.BoxConstraints? constraints;
  final material.ButtonStyle? style;
  final bool? isSelected;
  final material.Widget? selectedIcon;
  final material.WidgetStatesController? statesController;
  final material.Widget icon;
}

class Tooltip extends material.StatelessWidget {
  const Tooltip({
    super.key,
    this.message,
    this.richMessage,
    this.height,
    this.constraints,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.exitDuration,
    this.enableTapToDismiss = true,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    this.mouseCursor,
    this.ignorePointer,
    this.child,
  }) : assert(
          (message == null) != (richMessage == null),
          'Either `message` or `richMessage` must be specified',
        );

  final String? message;
  final material.InlineSpan? richMessage;
  final double? height;
  final material.BoxConstraints? constraints;
  final material.EdgeInsetsGeometry? padding;
  final material.EdgeInsetsGeometry? margin;
  final double? verticalOffset;
  final bool? preferBelow;
  final bool? excludeFromSemantics;
  final material.Decoration? decoration;
  final material.TextStyle? textStyle;
  final material.TextAlign? textAlign;
  final Duration? waitDuration;
  final Duration? showDuration;
  final Duration? exitDuration;
  final bool enableTapToDismiss;
  final material.TooltipTriggerMode? triggerMode;
  final bool? enableFeedback;
  final material.TooltipTriggeredCallback? onTriggered;
  final material.MouseCursor? mouseCursor;
  final bool? ignorePointer;
  final material.Widget? child;

  @override
  material.Widget build(material.BuildContext context) {
    return material.Tooltip(
      message: _localizedText(context, message),
      richMessage: richMessage,
      // ignore: deprecated_member_use
      height: height,
      constraints: constraints,
      padding: padding,
      margin: margin,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      decoration: decoration,
      textStyle: textStyle,
      textAlign: textAlign,
      waitDuration: waitDuration,
      showDuration: showDuration,
      exitDuration: exitDuration,
      enableTapToDismiss: enableTapToDismiss,
      triggerMode: triggerMode,
      enableFeedback: enableFeedback,
      onTriggered: onTriggered,
      mouseCursor: mouseCursor,
      ignorePointer: ignorePointer,
      child: child,
    );
  }
}

material.InputDecoration? _localizedDecoration(
  material.BuildContext context,
  material.InputDecoration? decoration,
) {
  if (decoration == null) return null;
  String? t(String? value) => _localizedText(context, value);
  return decoration.copyWith(
    labelText: t(decoration.labelText),
    helperText: t(decoration.helperText),
    hintText: t(decoration.hintText),
    errorText: t(decoration.errorText),
    prefixText: t(decoration.prefixText),
    suffixText: t(decoration.suffixText),
    counterText: t(decoration.counterText),
    semanticCounterText: t(decoration.semanticCounterText),
  );
}

String? _localizedText(material.BuildContext context, String? value) {
  if (value == null) return null;
  return AppStrings.maybeOf(context)?.t(value) ?? value;
}
