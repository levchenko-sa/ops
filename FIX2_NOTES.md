# OPS Control v9.5.6 fix2

Исправления по GitHub Actions run 31252994465:

- flutter_test добавлен в dev_dependencies;
- тесты report_parser и qr_parser используют flutter_test;
- исправлена типизация списка в object_history_screen.dart (Widget вместо Card-only list inference);
- DropdownButtonFormField переведены с deprecated value на initialValue;
- RadioListTile с deprecated groupValue/onChanged заменён на InkWell + ListTile;
- удалён неиспользуемый импорт material_item.dart из work_screen.dart;
- удалён неиспользуемый _profileReady из inventory_documents_screen.dart;
- удалён неиспользуемый _fmt из верхнего класса engineer_stock_screen.dart;
- build number: 9.5.6+2;
- GitHub Actions анализирует ошибки строго, но warnings/info не блокируют APK.
