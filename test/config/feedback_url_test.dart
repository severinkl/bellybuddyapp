import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/config/constants.dart';

void main() {
  test('feedbackFormUrl points at the Mailchimp survey', () {
    expect(
      AppConstants.feedbackFormUrl,
      'https://us20.list-manage.com/survey?u=526bdf1360ec4bf225504e006&id=d47032793c&attribution=false',
    );
  });
}
