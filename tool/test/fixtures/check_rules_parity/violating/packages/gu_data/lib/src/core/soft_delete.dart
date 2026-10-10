abstract final class SoftDelete {
  static const Set<String> affectedKeys = {
    FirestoreFields.isDeleted,
    FirestoreFields.deletedAt,
    FirestoreFields.deletedBy,
    FirestoreFields.updatedAt,
  };
}
