// Fixture: HC12c kapsam dışı — primitifleri yalnızca servis çağırır.
class AppFeedbackService {
  Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) =>
      showGuSheet<T>(context, builder: builder);

  Future<T?> showDialog<T>(BuildContext context, WidgetBuilder builder) =>
      showGuDialog<T>(context, builder: builder);

  Future<T?> showMenu<T>(BuildContext context, List<Widget> items) =>
      showGuPopMenu<T>(context, items: items);
}
