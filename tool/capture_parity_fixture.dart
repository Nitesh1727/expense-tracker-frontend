// Records the cloud backend's real answers for a matrix of queries against
// one account, together with that account's full dataset, so the parity test
// can load the same data into SQLite and check the local implementation
// returns identical results. Read-only against the cloud (login + GETs).
//
//   dart run tool/capture_parity_fixture.dart <apiBaseUrl> <email> <password>
import 'dart:convert';
import 'dart:io';

late String base;
late String token;
final client = HttpClient()..connectionTimeout = const Duration(seconds: 120);

Future<dynamic> call(String method, String path, {Map<String, String>? query, Object? body, bool raw = false}) async {
  final uri = Uri.parse('$base$path').replace(queryParameters: query);
  final req = await client.openUrl(method, uri);
  req.headers.set('content-type', 'application/json');
  if (method != 'POST' || path != '/auth/login/email') req.headers.set('authorization', 'Bearer $token');
  if (body != null) req.add(utf8.encode(jsonEncode(body)));
  final res = await req.close();
  final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
  if (res.statusCode >= 400) throw 'HTTP ${res.statusCode} $path ${utf8.decode(bytes)}';
  return raw ? bytes : jsonDecode(utf8.decode(bytes));
}

String iso(DateTime d) => d.toUtc().toIso8601String();
DateTime istMidnight(int y, int m, int d) => DateTime.utc(y, m, d).subtract(const Duration(hours: 5, minutes: 30));

Future<void> main(List<String> args) async {
  base = args[0];
  final login = await call('POST', '/auth/login/email', body: {'email': args[1], 'password': args[2]});
  token = login['token'];

  final categories = (await call('GET', '/categories'))['categories'] as List;
  final expenses = <Map<String, dynamic>>[];
  for (var page = 1;; page++) {
    final r = await call('GET', '/expenses', query: {'page': '$page', 'limit': '100'});
    expenses.addAll((r['items'] as List).cast<Map<String, dynamic>>());
    if (expenses.length >= r['total']) break;
  }
  stdout.writeln('dataset: ${expenses.length} expenses, ${categories.length} categories');

  final dates = expenses.map((e) => DateTime.parse(e['date'])).toList()..sort();
  final newest = dates.last, oldest = dates.first;
  final catIds = categories.map((c) => c['_id'] as String).toList();

  // Search terms drawn from the data itself so they're guaranteed to matter.
  final words = <String, int>{};
  for (final e in expenses) {
    for (final w in (e['description'] as String).toLowerCase().split(RegExp(r'\s+'))) {
      if (w.length >= 3) words[w] = (words[w] ?? 0) + 1;
    }
  }
  final topWords = (words.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).take(4).toList();
  final amounts = <double, int>{};
  for (final e in expenses) {
    final a = (e['amount'] as num).toDouble();
    amounts[a] = (amounts[a] ?? 0) + 1;
  }
  final topAmounts = (amounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).take(3).toList();
  final decimalAmount = amounts.keys.firstWhere((a) => a != a.roundToDouble(), orElse: () => topAmounts.first);
  // Instants of real expenses double as inclusive-from / exclusive-to probes.
  final probe = DateTime.parse(expenses[expenses.length ~/ 2]['date']);

  // Anchors straddling IST day/week/month/year edges (23:59:59.999, 00:00, 00:15 IST).
  final edgeDays = <DateTime>[
    istMidnight(newest.year, newest.month, 1),
    istMidnight(newest.year, 1, 1),
    istMidnight(newest.year - 1, 12, 31).add(const Duration(days: 1)),
    for (var d = newest.subtract(const Duration(days: 8)); d.isBefore(newest); d = d.add(const Duration(days: 1)))
      istMidnight(d.year, d.month, d.day),
  ];
  final anchors = <DateTime>{
    newest, oldest, probe,
    for (final e in edgeDays) ...[
      e.subtract(const Duration(milliseconds: 1)),
      e,
      e.add(const Duration(minutes: 15)),
    ],
  }.toList();

  final cases = <Map<String, dynamic>>[];
  Future<void> add(String op, String name, Map<String, String> q) async {
    final path = {'list': '/expenses', 'daily': '/expenses/daily-summary', 'summary': '/analytics/summary', 'trend': '/analytics/trend'}[op]!;
    cases.add({'op': op, 'name': name, 'query': q, 'expected': await call('GET', path, query: q)});
  }

  final periodStart = istMidnight(newest.year, newest.month, 1);
  final ranges = {
    'month': {'from': iso(periodStart), 'to': iso(istMidnight(newest.year, newest.month + 1, 1))},
    'from-only': {'from': iso(probe)},
    'to-only': {'to': iso(probe)},
    'exact-probe-day': {'from': iso(probe), 'to': iso(probe.add(const Duration(days: 1)))},
    'year': {'from': iso(istMidnight(newest.year, 1, 1)), 'to': iso(istMidnight(newest.year + 1, 1, 1))},
    'all': <String, String>{},
  };

  for (final r in ranges.entries) {
    for (final page in [1, 2]) {
      await add('list', 'list ${r.key} p$page', {...r.value, 'page': '$page', 'limit': '20'});
    }
    await add('list', 'list ${r.key} limit100', {...r.value, 'limit': '100'});
    await add('daily', 'daily ${r.key} p1', {...r.value, 'page': '1', 'limit': '15'});
    await add('daily', 'daily ${r.key} p2', {...r.value, 'page': '2', 'limit': '15'});
  }
  await add('list', 'list last page', {'page': '${(expenses.length / 20).ceil()}', 'limit': '20'});
  await add('list', 'list beyond last page', {'page': '${(expenses.length / 20).ceil() + 5}', 'limit': '20'});
  await add('daily', 'daily limit60', {'limit': '60'});

  for (final (i, id) in catIds.indexed) {
    await add('list', 'list single category #$i', {'categoryId': id, 'limit': '20'});
    await add('list', 'list single category #$i in month', {'categoryId': id, ...ranges['month']!});
  }
  await add('list', 'list 2 categories', {'categoryIds': catIds.take(2).join(','), 'limit': '30'});
  await add('list', 'list 3 categories page2', {'categoryIds': catIds.take(3).join(','), 'page': '2', 'limit': '20'});
  await add('list', 'list categoryIds beats categoryId', {'categoryId': catIds.last, 'categoryIds': catIds.first});
  await add('daily', 'daily 2 categories', {'categoryIds': catIds.take(2).join(',')});
  await add('daily', 'daily 3 categories in year', {'categoryIds': catIds.take(3).join(','), ...ranges['year']!});

  for (final w in topWords) {
    await add('list', 'q word $w', {'q': w});
    await add('list', 'q word UPPER $w', {'q': w.toUpperCase()});
    await add('list', 'q partial ${w.substring(0, 3)}', {'q': w.substring(0, 3)});
  }
  await add('list', 'q regex chars', {'q': 'coffee (2)'});
  await add('list', 'q dot star', {'q': '.*'});
  await add('list', 'q no match', {'q': 'zzzqqqxxx'});
  for (final a in topAmounts) {
    await add('list', 'q amount $a', {'q': '$a'});
  }
  await add('list', 'q amount decimal $decimalAmount', {'q': '$decimalAmount'});
  await add('list', 'q numeric substring', {'q': '${topAmounts.first.toInt()}'.substring(0, 1)});
  await add('list', 'combined cat+q+month', {'categoryId': catIds.first, 'q': topWords.first, ...ranges['month']!});
  await add('list', 'combined cats+amount+year', {'categoryIds': catIds.take(3).join(','), 'q': '${topAmounts.first}', ...ranges['year']!});

  for (final a in anchors) {
    for (final p in ['day', 'week', 'month', 'year']) {
      await add('summary', 'summary $p @${iso(a)}', {'period': p, 'anchor': iso(a)});
    }
    for (final p in ['week', 'month', 'year']) {
      await add('trend', 'trend $p @${iso(a)}', {'period': p, 'anchor': iso(a)});
    }
  }

  final exports = <Map<String, dynamic>>[];
  for (final r in ['month', 'year', 'all']) {
    final q = {...ranges[r]!, 'label': 'Parity $r'};
    final bytes = await call('GET', '/export/xlsx', query: q, raw: true) as List<int>;
    exports.add({'query': q, 'xlsxBase64': base64Encode(bytes)});
  }

  final out = File('test/parity/fixtures.json');
  await out.writeAsString(jsonEncode({
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'categories': categories,
    'expenses': expenses,
    'cases': cases,
    'exports': exports,
  }));
  stdout.writeln('wrote ${cases.length} cases + ${exports.length} exports -> ${out.path} (${out.lengthSync() ~/ 1024} KB)');
  client.close();
}
