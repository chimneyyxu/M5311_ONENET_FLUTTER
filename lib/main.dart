import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'pages/map/map_my_location.dart';

final List<Permission> needPermissionList = [
  Permission.location,
  Permission.storage,
  Permission.phone,
];

class AMapDemo extends StatefulWidget {
  AMapDemo({Key? key}) : super(key: key);
  @override
  DemoWidget createState() => DemoWidget();
}

class DemoWidget extends State<AMapDemo> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    WidgetsBinding.instance.addObserver(this);
    Timer(const Duration(seconds: 5), () {
      FlutterBackgroundService().invoke("setAsBackground");
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _checkPermissions();
  }

  @override
  void dispose() {
    super.dispose();
    //3. 页面销毁时，移出监听者
    WidgetsBinding.instance.removeObserver(this);
  }

  //监听程序进入前后台的状态改变的方法
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    switch (state) {
      //进入应用时候不会触发该状态 应用程序处于可见状态，并且可以响应用户的输入事件。它相当于 Android 中Activity的onResume
      case AppLifecycleState.resumed:
        print("应用进入前台======");
        Timer(const Duration(seconds: 10), () {
          FlutterBackgroundService().invoke("setAsBackground");
        });
        break;
      //应用状态处于闲置状态，并且没有用户的输入事件，
      // 注意：这个状态切换到 前后台 会触发，所以流程应该是先冻结窗口，然后停止UI
      case AppLifecycleState.inactive:
        print("应用处于闲置状态，这种状态的应用应该假设他们可能在任何时候暂停 切换到后台会触发======");
        break;
      //当前页面即将退出
      case AppLifecycleState.detached:
        FlutterBackgroundService().invoke("setAsForeground");
        print("当前页面即将退出======");
        break;
      // 应用程序处于不可见状态
      case AppLifecycleState.paused:
        FlutterBackgroundService().invoke("setAsForeground");
        print("应用处于不可见状态 后台======");
        break;
    }
  }

  void _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await needPermissionList.request();
    statuses.forEach((key, value) {
      print('$key premissionStatus is $value');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '高德地图',
      home: Scaffold(
        appBar: AppBar(title: const Text('高德地图')),
        body: Body(),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(AMapDemo());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: false,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: '实时监控',
      initialNotificationContent: '开启',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      // onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // SharedPreferences preferences = await SharedPreferences.getInstance();
  // await preferences.setString("hello", "world");

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_bg_service_small');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  get() async {
    var da = 1;
    var url_getdata = Uri.https(
        'iot-api.heclouds.com',
        'thingmodel/query-device-property',
        {"product_id": "6FqaGR4PX6", "device_name": "m5311_gps"});
    var response = await http.get(
      url_getdata,
      headers: {
        "Authorization":
            "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
      },
    );
    if (response.statusCode == 200) {
      print(response.body);
      final map = jsonDecode(response.body);
      List a = map["data"];
      a.forEach((element) {
        print(element["identifier"]);
        if (element["identifier"] == "socpe") {
          final d = jsonDecode(element["value"]);
          da = d["socpe"] ?? 1;
          print(da);
        }
      });
    } else {
      print('Request failed with status: ${response.statusCode}.');
      print(response.body);
    }
    return da;
  }

  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails('your channel id', 'your channel name',
          channelDescription: 'your channel description',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker');

  NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        get().then((value) => {
              if (value == 0)
                {
                  flutterLocalNotificationsPlugin.show(
                    888,
                    null,
                    '不在范围内',
                    notificationDetails,
                  )
                }
              else
                {print("000")}
            });
      }
    }
  });
}
