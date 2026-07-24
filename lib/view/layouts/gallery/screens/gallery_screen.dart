import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/empty_state.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// The widget gallery: every design-system widget in its states, for eyeballing
/// on device. Debug builds only, so labels are deliberately not localized.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final TextEditingController _text = TextEditingController();
  bool _toggle = true;
  int _page = 0;
  String? _notice;

  static const _icons = [
    AppIcons.micFill,
    AppIcons.mic,
    AppIcons.waveform,
    AppIcons.houseFill,
    AppIcons.gearshapeFill,
    AppIcons.chevronBackward,
    AppIcons.chevronForward,
    AppIcons.playFill,
    AppIcons.pauseFill,
    AppIcons.stopFill,
    AppIcons.squareFill,
    AppIcons.xmark,
    AppIcons.checkmark,
    AppIcons.arrowUpRight,
    AppIcons.arrowCounterclockwise,
    AppIcons.trash,
    AppIcons.ellipsis,
    AppIcons.docOnDoc,
    AppIcons.globe,
    AppIcons.moonFill,
    AppIcons.sunMax,
    AppIcons.icloud,
    AppIcons.calendar,
    AppIcons.textformat,
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _section(String label) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
      child: Text(label.toUpperCase(), style: AppType.eyebrow.copyWith(color: theme.textSecondary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.background,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppTopBar.heightOf(context) + AppSpacing.sm,
              AppSpacing.lg,
              120,
            ),
            children: [
              _section('Icons'),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [for (final icon in _icons) AppIcon(icon, color: theme.text)],
              ),
              _section('Buttons'),
              AppButton(label: 'Primary', onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Secondary', variant: AppButtonVariant.secondary, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Danger', variant: AppButtonVariant.danger, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              const AppButton(label: 'Disabled', onPressed: null),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Loading', isLoading: true, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'With icon',
                icon: AppIcons.arrowCounterclockwise,
                expand: false,
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  AppIconButton(icon: AppIcons.pauseFill, onTap: () {}),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(icon: AppIcons.arrowCounterclockwise, onTap: () {}),
                ],
              ),
              _section('Toggle'),
              Row(
                children: [
                  AppToggle(value: _toggle, onChanged: (v) => setState(() => _toggle = v)),
                  const SizedBox(width: AppSpacing.lg),
                  const AppToggle(value: true, onChanged: null),
                ],
              ),
              _section('Text field'),
              AppTextField(controller: _text, placeholder: 'Entry title'),
              _section('Spinner'),
              const Align(alignment: Alignment.centerLeft, child: AppSpinner()),
              _section('Page indicator'),
              Touchable(
                onTap: () => setState(() => _page = (_page + 1) % 4),
                child: PageIndicator(count: 4, index: _page),
              ),
              _section('Notice'),
              AppButton(
                label: 'Show notice',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _notice = 'Couldn\'t save that entry.'),
              ),
              AppNotice(message: _notice, onDismiss: () => setState(() => _notice = null)),
              _section('Menu'),
              Align(
                alignment: Alignment.centerLeft,
                child: AppMenuButton(
                  icon: AppIcons.ellipsis,
                  items: const [
                    AppMenuItem(label: 'Rename', icon: AppIcons.textformat),
                    AppMenuItem(label: 'Re-transcribe', icon: AppIcons.arrowCounterclockwise),
                    AppMenuItem(label: 'Delete', icon: AppIcons.trash, destructive: true),
                  ],
                  onSelected: (_) {},
                ),
              ),
              _section('Wave glyph'),
              const Align(alignment: Alignment.centerLeft, child: WaveGlyph()),
              _section('Empty state'),
              const EmptyState(
                visual: WaveGlyph(),
                title: 'Nothing here yet',
                message: 'Speak your mind.',
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _GalleryTopBar()),
        ],
      ),
    );
  }
}

class _GalleryTopBar extends StatelessWidget {
  const _GalleryTopBar();

  @override
  Widget build(BuildContext context) {
    return const AppTopBar(frosted: true, leading: AppBackButton());
  }
}
