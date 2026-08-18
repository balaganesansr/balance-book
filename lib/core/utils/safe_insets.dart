import 'package:flutter/material.dart';

/// Helpers for keeping content clear of the system bars.
///
/// The app draws edge-to-edge (enforced from Android 15), so the gesture pill
/// or the three-button navigation bar sits *over* the bottom of every screen.
/// Anything the user must be able to read or tap has to account for it.
///
/// [MediaQuery.viewPaddingOf] is used rather than `paddingOf` on purpose:
/// `padding` collapses to zero once the keyboard covers the system bar, which
/// would make a sheet's buttons jump as the keyboard opens and closes.
/// `viewPadding` stays constant.
extension SafeInsets on BuildContext {
  /// Height of the system navigation bar / gesture pill.
  double get bottomInset => MediaQuery.viewPaddingOf(this).bottom;

  /// Height of the status bar / notch.
  double get topInset => MediaQuery.viewPaddingOf(this).top;

  /// Height of the on-screen keyboard, if any.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// Padding a modal bottom sheet needs below its content.
  ///
  /// `showModalBottomSheet(useSafeArea: true)` only avoids intrusions at the
  /// top, left and right. The sheet still runs under the navigation bar, so
  /// the bottom is ours to handle. When the keyboard is up it already covers
  /// the navigation bar, so the two are not additive.
  double sheetBottomPadding([double base = 24]) =>
      base + (keyboardInset > 0 ? keyboardInset : bottomInset);

  /// Bottom padding for a scrollable on a screen with no bottom navigation.
  ///
  /// The list still scrolls edge-to-edge; only its content is inset, so the
  /// last row can be scrolled clear of the navigation bar.
  double scrollBottomPadding([double base = 32]) => base + bottomInset;
}
