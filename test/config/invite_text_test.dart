import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';

void main() {
  test('the invite text ends with the link and names the app', () {
    expect(AppConstants.inviteUrl, 'https://bellybuddy.at');
    expect(AppConstants.inviteShareText, endsWith('https://bellybuddy.at'));
    expect(AppConstants.inviteShareText, contains('Belly Buddy'));
  });
}
