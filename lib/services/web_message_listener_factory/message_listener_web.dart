import 'dart:html' as html;

void setupWebMessageListener(
    Function(String jobId, Map<String, dynamic> data) onCheckGrades) {
  html.window.onMessage.listen((event) {
    try {
      final data = event.data;
      if (data != null && data['type'] == 'CHECK_GRADES_TRIGGER') {
        final jobId = data['jobId']?.toString() ?? '';
        final payloadData = Map<String, dynamic>.from(data['data'] ?? {});
        onCheckGrades(jobId, payloadData);
      }
    } catch (_) {}
  });
}
