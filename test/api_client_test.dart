import 'dart:convert';

import 'package:elrashedy_pos/core/api_client.dart';
import 'package:elrashedy_pos/core/ticket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Ticket ticket() => Ticket(
      clientId: '3f2b8c1e-0000-4000-8000-000000000001',
      userId: 7,
      branchId: 3,
      branchName: 'فرع',
      orderType: 'takeaway',
      payment: 'cash',
      placedAt: DateTime.utc(2026, 3, 10, 14, 30),
      lines: [TicketLine(productId: 11, name: 'شاورما', price: '45.50', qty: '2')],
    );

void main() {
  group('base url handling', () {
    test('adds https and strips trailing slashes', () {
      expect(ApiClient.normalizeBaseUrl('app.herokuapp.com/'), 'https://app.herokuapp.com');
      expect(ApiClient.normalizeBaseUrl(' http://localhost:8000/// '), 'http://localhost:8000');
      expect(ApiClient.normalizeBaseUrl(''), '');
    });

    test('resolves site-relative menu images against the server', () {
      final api = ApiClient(baseUrl: 'https://app.herokuapp.com');
      expect(api.resolveUrl('/media/p.jpg'), 'https://app.herokuapp.com/media/p.jpg');
      expect(api.resolveUrl('media/p.jpg'), 'https://app.herokuapp.com/media/p.jpg');
      expect(api.resolveUrl('https://cdn/p.jpg'), 'https://cdn/p.jpg');
      expect(api.resolveUrl(null), '');
    });
  });

  test('login posts credentials and the device name, then returns the token', () async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse({
          'token': 'pos_abc',
          'user': {'id': 7, 'username': 'cashier', 'display_name': 'أحمد', 'permissions': {}},
        }, 200);
      }),
    );
    final result = await api.login(username: 'cashier', password: 'secret', deviceName: 'كاشير 1');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/pos-api/v1/auth/login/');
    expect(jsonDecode(captured.body), {'username': 'cashier', 'password': 'secret', 'device_name': 'كاشير 1'});
    expect(result.token, 'pos_abc');
    expect(result.user.displayName, 'أحمد');
  });

  test('authenticated calls send the device token', () async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      token: 'pos_abc',
      httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse({'branches': [], 'user': {'id': 7, 'username': 'c'}}, 200);
      }),
    );
    await api.bootstrap();
    expect(captured.headers['Authorization'], 'Token pos_abc');
    expect(captured.url.path, '/pos-api/v1/bootstrap/');
  });

  group('sync', () {
    test('a new sale returns 201 and the server id', () async {
      late Map<String, dynamic> payload;
      final api = ApiClient(
        baseUrl: 'https://app.herokuapp.com',
        token: 'pos_abc',
        httpClient: MockClient((request) async {
          payload = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
          return jsonResponse({'id': 4321, 'total': '91.00'}, 201);
        }),
      );
      final result = await api.syncTicket(ticket());
      expect(result.saleId, 4321);
      expect(result.created, isTrue);
      expect(payload, ticket().toSyncPayload());
    });

    test('an idempotent retry returns 200 and is not counted as a new sale', () async {
      final api = ApiClient(
        baseUrl: 'https://app.herokuapp.com',
        httpClient: MockClient((request) async => jsonResponse({'id': 4321, 'total': '91.00'}, 200)),
      );
      final result = await api.syncTicket(ticket());
      expect(result.created, isFalse);
      expect(result.saleId, 4321);
    });

    test('a price conflict surfaces the server message as a 409', () async {
      final api = ApiClient(
        baseUrl: 'https://app.herokuapp.com',
        httpClient: MockClient((request) async => jsonResponse({'error': 'سعر الصنف تغير. راجع المدير.'}, 409)),
      );
      await expectLater(
        api.syncTicket(ticket()),
        throwsA(isA<ApiException>()
            .having((error) => error.isConflict, 'isConflict', isTrue)
            .having((error) => error.message, 'message', 'سعر الصنف تغير. راجع المدير.')),
      );
    });

    test('an expired token is an auth failure so the queue stops', () async {
      final api = ApiClient(
        baseUrl: 'https://app.herokuapp.com',
        httpClient: MockClient((request) async => http.Response('Unauthorized', 401)),
      );
      await expectLater(
        api.syncTicket(ticket()),
        throwsA(isA<ApiException>().having((error) => error.isAuth, 'isAuth', isTrue)),
      );
    });
  });

  test('catalog keeps only menu-section products, exactly like the browser', () async {
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/pos-api/v1/catalog/3/');
        return jsonResponse({
          'products': [
            {
              'id': 1,
              'name': 'شاورما',
              'price': '45.50',
              'category_id': 'section-2',
              'categories': [
                {'id': 'section-2', 'name': 'سندوتشات'},
              ],
            },
            {'id': 2, 'name': 'مخزون', 'price': '10.00', 'category_id': '9'},
          ],
        }, 200);
      }),
    );
    final products = await api.catalog(3);
    expect(products.length, 1);
    expect(products.single.name, 'شاورما');
    expect(products.single.categoryIds, ['section-2']);
  });

  test('shift summary parses the staged totals', () async {
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['branch'], '3');
        return jsonResponse({
          'operational_date': '2026-03-10',
          'sales': 100.0,
          'expenses': 10.0,
          'advances': 20.0,
          'suppliers': 30.0,
          'closed': true,
          'cash_in_id': 55,
        }, 200);
      }),
    );
    final summary = await api.shiftSummary(3);
    expect(summary.operationalDate, '2026-03-10');
    expect(summary.sales, '100.0');
    expect(summary.closed, isTrue);
    expect(summary.cashInId, 55);
  });

  test('shift movements post the branch with the movement', () async {
    late Map<String, dynamic> payload;
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      httpClient: MockClient((request) async {
        payload = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
        return jsonResponse({'ok': true}, 201);
      }),
    );
    await api.addExpense(branchId: 3, accountId: 2, amount: '10.00', reason: 'كهرباء');
    expect(payload, {'branch': 3, 'account': 2, 'amount': '10.00', 'reason': 'كهرباء'});
  });

  test('appLatest degrades to null when no release is published', () async {
    final api = ApiClient(
      baseUrl: 'https://app.herokuapp.com',
      httpClient: MockClient((request) async => jsonResponse({'available': false}, 503)),
    );
    expect(await api.appLatest(), isNull);
  });
}