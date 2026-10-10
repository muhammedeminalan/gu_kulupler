import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feedback_service_provider.g.dart';

/// View katmanının [FeedbackService] köprüsü (CD-93): view ve view
/// mixin'leri `ref.read(feedbackServiceProvider)` kullanır; view'da `GetIt.I`
/// yoktur (HC13). Testte
/// `feedbackServiceProvider.overrideWithValue(FakeFeedbackService())`.
@Riverpod(keepAlive: true)
FeedbackService feedbackService(Ref ref) => GetIt.I<FeedbackService>();
