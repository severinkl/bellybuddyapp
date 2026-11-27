import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/feedback.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feedback_context_provider.dart';
import '../../services/feedback_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_chip_selector.dart';
import '../../widgets/common/bb_labeled_field.dart';
import '../shares/widgets/share_terms_form.dart' show ShareFormHeading;

/// „Feedback geben": a category, the message (at most
/// [AppConstants.feedbackMaxLength] characters a person sees), „Antwort
/// erwünscht" when the account has an address, and what is sent along.
/// Sent, it pops back and thanks on the screen below; refused, the reason
/// stays on the form with the text. Nothing is stored on the device, and
/// neither the text, the category nor the address is logged.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  static Key categoryKey(FeedbackCategory category) =>
      Key('feedback_category_${category.jsonValue}');
  static const messageKey = Key('feedback_message');
  static const replyKey = Key('feedback_reply');
  static const sendKey = Key('feedback_send');

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _log = AppLogger('FeedbackScreen');
  static const _generic = 'Das hat nicht geklappt. Versuch es später nochmal.';
  static const _thanks = 'Danke! Dein Feedback ist angekommen.';

  final _message = TextEditingController();
  FeedbackCategory? _category;
  bool _reply = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending && _category != null && _message.text.trim().isNotEmpty;

  Future<void> _send() async {
    final category = _category;
    final text = _message.text.trim();
    if (_sending || category == null || text.isEmpty) return;
    final email = _addressOf(ref.read(currentUserProvider)?.email);
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    // Taken before the await: the screen may be gone when the call returns.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    try {
      await ref
          .read(feedbackServiceProvider)
          .send(
            category: category,
            message: text,
            replyWanted: _reply && email != null,
            context: await ref.read(feedbackContextProvider.future),
          );
    } on FeedbackException catch (e) {
      _log.warn('not sent (${e.status ?? 'no answer'})');
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _messageFor(e);
        });
      }
      return;
    } catch (_) {
      // Only the outcome: the error could echo what was sent.
      _log.warn('not sent (error)');
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _generic;
        });
      }
      return;
    }
    _log.debug('sent');
    // Still on its way back the screen is mounted but not on top: popping
    // then would close the screen below.
    if (mounted && (route?.isCurrent ?? false)) router.pop();
    messenger.showSnackBar(const SnackBar(content: Text(_thanks)));
  }

  /// Core's text for a refusal (4xx), else the generic line.
  static String _messageFor(FeedbackException e) {
    final status = e.status;
    final isRefusal = status != null && status >= 400 && status < 500;
    return isRefusal ? e.message ?? _generic : _generic;
  }

  /// The account's address for a reply; null without one.
  static String? _addressOf(String? email) =>
      email == null || email.isEmpty ? null : email;

  @override
  Widget build(BuildContext context) {
    final email = _addressOf(
      ref.watch(currentUserProvider.select((u) => u?.email)),
    );
    final feedbackContext = ref.watch(feedbackContextProvider);
    final error = _error;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Feedback geben'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppConstants.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShareFormHeading('Worum geht es?'),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    children: [
                      for (final category in FeedbackCategory.values)
                        BbFilterChip(
                          key: FeedbackScreen.categoryKey(category),
                          label: category.label,
                          selected: _category == category,
                          onSelected: (_) {
                            if (_sending) return;
                            setState(() => _category = category);
                          },
                        ),
                    ],
                  ),
                  AppConstants.gap24,
                  // The field below carries the label for screen readers.
                  const ExcludeSemantics(
                    child: ShareFormHeading('Deine Nachricht'),
                  ),
                  BbLabeledField(
                    label: 'Deine Nachricht',
                    child: TextField(
                      key: FeedbackScreen.messageKey,
                      controller: _message,
                      enabled: !_sending,
                      minLines: 4,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: AppConstants.feedbackMaxLength,
                      onChanged: (_) => setState(() {}),
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => Text(
                            '$currentLength / $maxLength',
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeCaption,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                      decoration: const InputDecoration(
                        hintText:
                            'Was ist dir aufgefallen, was wünschst du dir?',
                      ),
                    ),
                  ),
                  AppConstants.gap8,
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: AppConstants.iconSizeSm,
                        color: AppTheme.mutedForeground,
                      ),
                      SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: Text(
                          'Bitte schreib hier keine Gesundheitsdaten '
                          'hinein, die du nicht teilen möchtest.',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeCaptionLG,
                            color: AppTheme.mutedForeground,
                            height: AppTheme.lineHeightBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (email != null) ...[
                    AppConstants.gap16,
                    SwitchListTile(
                      key: FeedbackScreen.replyKey,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Antwort erwünscht'),
                      subtitle: Text('Wir antworten an $email.'),
                      value: _reply,
                      onChanged: _sending
                          ? null
                          : (v) => setState(() => _reply = v),
                    ),
                  ],
                  AppConstants.gap24,
                  _SentAlong(feedbackContext),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: AppConstants.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: AppTheme.destructive,
                          height: AppTheme.lineHeightBody,
                        ),
                      ),
                    ),
                    AppConstants.gap8,
                  ],
                  BbButton(
                    tapKey: FeedbackScreen.sendKey,
                    label: 'Senden',
                    isLoading: _sending,
                    onPressed: _canSend ? () => unawaited(_send()) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// „Das wird mitgeschickt:" with the app version and the system („…" while
/// they load; the provider reports unreadable values itself).
class _SentAlong extends StatelessWidget {
  const _SentAlong(this.sent);

  final AsyncValue<FeedbackContext> sent;

  @override
  Widget build(BuildContext context) {
    final (version, system) = switch (sent) {
      AsyncData(:final value) => (value.appVersion, value.systemLabel),
      _ => ('…', '…'),
    };
    const style = TextStyle(
      fontSize: AppTheme.fontSizeBody,
      color: AppTheme.mutedForeground,
      height: AppTheme.lineHeightBody,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Das wird mitgeschickt:',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        AppConstants.gap4,
        Text('App-Version $version', style: style),
        Text('System: $system', style: style),
        const Text('Keine Tagebuch- oder Gesundheitsdaten.', style: style),
      ],
    );
  }
}
