import '../api/api_client.dart';
import '../api/models/approvals.dart';

class ApprovalsRepository {
  ApprovalsRepository(this._client);

  final ApiClient _client;

  Future<Approvals> load() async => Approvals.fromJson(await _client.get('/approvals'));
}
