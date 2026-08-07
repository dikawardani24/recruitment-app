import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'di.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$setupDependencies',
  preferRelativeImports: true,
  asExtension: true,
)
void setupDependencies() async {
  GetIt.instance.$setupDependencies();
}
