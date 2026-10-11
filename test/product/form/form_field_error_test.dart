// T-13 · FormFieldError / SubmitError: PLAN §12.1 "Form State kalıbı"
// üyeleri (ViewModel'ler `errors: Map<XField, FormFieldError>` tutar; metne
// çeviri view'dadır).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

void main() {
  group('T-13 · FormFieldError', () {
    test('üyeler PLAN §12.1 listesiyle aynı ve aynı sırada', () {
      expect(
        [for (final error in FormFieldError.values) error.name],
        [
          'required',
          'tooShort',
          'tooLong',
          'invalidEmail',
          'domainNotAllowed',
          'passwordWeak',
          'passwordMismatch',
          'consentMissing',
          'limitExceeded',
          'invalidFormat',
          'endBeforeStart',
          'capacityBelowGoing',
        ],
      );
    });

    test('SubmitError üyeleri PLAN §12.1 ile aynı', () {
      expect(
        [for (final error in SubmitError.values) error.name],
        ['network', 'permission', 'conflict', 'unknown'],
      );
    });
  });
}
