/// Design: EVT-01
class EventListView {
  EventListView(this.id);
  final String id;
  late final open = GuKey.action('EVT-01.open.${id}');
}
