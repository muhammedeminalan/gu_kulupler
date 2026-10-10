/// Design: CLB-01
class ClubListView {
  ClubListView(this.id);
  final String id;
  late final join = GuKey.action('CLB-01.join.${id}');
  final search = GuKey.action('CLB-01.search');
  late final myClub = GuKey.action('CLB-01.myClub.$id');
}
