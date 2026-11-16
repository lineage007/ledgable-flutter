import '../api/api_client.dart';
import '../api/models/dashboard.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final ApiClient _client;

  Future<Dashboard> load() async => Dashboard.fromJson(await _client.get('/dashboard'));
}
