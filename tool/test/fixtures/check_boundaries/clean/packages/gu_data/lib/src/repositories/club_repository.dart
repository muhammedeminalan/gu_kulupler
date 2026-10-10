// Fixture: repository arayüzü SDK tipi görmez.
import '../models/club_model.dart';

abstract interface class ClubRepository {
  Future<List<ClubModel>> fetchActiveClubs();
}
