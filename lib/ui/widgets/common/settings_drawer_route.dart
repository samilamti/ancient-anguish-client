import 'package:flutter/material.dart';

/// Shows [pane] as a right-docked drawer panel — the same presentation as
/// the HomeScreen settings endDrawer — instead of a fullscreen route.
///
/// The panel is an ordinary modal route, so editors pushed from inside it
/// (rule editor, alias designer, …) still open fullscreen and pop back to
/// the still-open panel. Dismissal: the scrim, Escape (the panes carry
/// their own [EscapeDismiss]), or the pane AppBar's back button.
Future<void> openSettingsDrawer(BuildContext context, Widget pane) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.of(context).size.width;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: screenWidth < 540 ? screenWidth * 0.9 : 480,
          height: double.infinity,
          child: Material(
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SafeArea(child: pane),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, panel) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: panel,
      );
    },
  );
}
