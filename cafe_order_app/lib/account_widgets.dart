import 'package:flutter/material.dart';

class AccountFrame extends StatelessWidget {
  const AccountFrame({
    super.key,
    required this.title,
    required this.photo,
    required this.child,
  });

  final String title;
  final String photo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: BackButton(color: colors.onSurface),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontal = viewport.maxWidth >= 720 ? 32.0 : 16.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: LayoutBuilder(
                        builder: (context, panel) {
                          final wide = panel.maxWidth >= 770;
                          final photoWidth = wide ? panel.maxWidth * .43 : 0.0;
                          return ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 1000 : 510,
                            ),
                            child: Material(
                              color: colors.surface,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: colors.outlineVariant),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Stack(
                                children: [
                                  if (wide)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: photoWidth,
                                      child: _AccountPhoto(photo: photo),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      photoWidth + (wide ? 48 : 24),
                                      wide ? 44 : 24,
                                      wide ? 48 : 24,
                                      wide ? 44 : 24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!wide) ...[
                                          const _AccountMark(),
                                          const SizedBox(height: 24),
                                        ],
                                        Semantics(
                                          header: true,
                                          child: Text(
                                            title,
                                            style:
                                                theme.textTheme.headlineLarge,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        child,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountPhoto extends StatelessWidget {
  const _AccountPhoto({required this.photo});

  final String photo;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF354638),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(photo, fit: BoxFit.cover, excludeFromSemantics: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x002C1C16), Color(0xE62C1C16)],
              stops: [.35, 1],
            ),
          ),
        ),
        const Positioned(
          left: 28,
          right: 28,
          bottom: 28,
          child: _AccountMark(onPhoto: true),
        ),
      ],
    ),
  );
}

class _AccountMark extends StatelessWidget {
  const _AccountMark({this.onPhoto = false});

  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = onPhoto ? const Color(0xFFFFF8ED) : theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: onPhoto ? const Color(0x26FFF8ED) : const Color(0xFFE7EBDD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.coffee_outlined, color: ink, size: 22),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Cà Phê Mây',
            style: theme.textTheme.titleLarge?.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}

class AccountFormError extends StatelessWidget {
  const AccountFormError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountTag extends StatelessWidget {
  const AccountTag({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
  });

  final String label;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = active ? const Color(0xFF354638) : const Color(0xFF5C4A3E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7EBDD) : const Color(0xFFF1E8DB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
