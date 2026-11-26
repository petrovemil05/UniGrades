import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}

void openPostFormInNewTab(String actionUrl, Map<String, String> fields) {
  final form = html.FormElement()
    ..method = 'POST'
    ..action = actionUrl
    ..target = '_blank'
    ..style.display = 'none';

  fields.forEach((key, value) {
    final input = html.InputElement()
      ..type = 'hidden'
      ..name = key
      ..value = value;
    form.children.add(input);
  });

  html.document.body?.children.add(form);
  form.submit();
  form.remove();
}
