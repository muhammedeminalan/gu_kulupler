/// Design: FED-01
class FeedView {
  FeedView(this.id);
  final String id;
  late final like = GuKey.action('FED-01.like.$id');
  final bogus = GuKey.action('FED-01.bogus');
  final demo = GuKey.action('FED-01.demoOnly');
}
