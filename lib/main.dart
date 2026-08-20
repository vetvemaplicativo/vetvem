import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/routes/app_pages.dart';
import 'app/services/auth_service.dart';
import 'app/services/ibge_service.dart';
import 'app/services/taxonomy_service.dart';
import 'app/theme/app_theme.dart';
import 'app/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Get.putAsync(() async => AuthService());
  await Get.putAsync(() => IbgeService().init());
  await Get.putAsync(() => TaxonomyService().init());
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const VetVemApp());
}

class VetVemApp extends StatelessWidget {
  const VetVemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'VetVem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 250),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
      builder: (context, child) => OfflineBanner(child: child!),
    );
  }
}
