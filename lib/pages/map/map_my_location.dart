import 'dart:async';
import 'dart:convert';
//import 'dart:html';
//import 'dart:math';
//import 'dart:ffi';
//import 'dart:html';
//import 'dart:io';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
//import '/base_page.dart';
import '/const_config.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:location_service_check/location_service_check.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:wifi_scan/wifi_scan.dart';
// class MyLocationPage extends  {
//    MyLocationPage(String title, String subTitle) : super(title, subTitle);
//   @override
//   Widget build(BuildContext context) => _Body();
// }

class Body extends StatefulWidget {
  Body({Key? key}) : super(key: key);
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  Map<String, Object>? _locationResult;
  StreamSubscription<Map<String, Object>>? _locationListener;
  AMapFlutterLocation _locationPlugin = new AMapFlutterLocation();
  AMapController? _mapController;
  //需要先设置一个空的map赋值给AMapWidget的markers，否则后续无法添加marker
  final Map<String, Marker> _markers = <String, Marker>{};
  String showmesg = "";
  String mes = "";
  double vol = 0; //电量
  double? mlon; //目标位置
  double? mlat;
  double? lon; //我的位置
  double? lat;
  bool startlocat = false; //开启我的位置
  double zoom = 13; //缩放等级
  double tilt = 30.0;
  double s = 240;
  bool show_w = true;
  Timer? real_timer; //实时更新定时器
  Timer? lo_time; //检查位置服务
  String tim = "00";
  String wifi_data1 = "";
  String wifi_data2 = "";
  String wifi_data3 = "";
  String wifi_data4 = "";
  String wifi_data5 = "";
  String wifi_data6 = "";
  List<String> accessPoints = []; //扫描结果
  String _wifiValue = '';
  StateSetter? aState; //用于 局部更新
  OverlayEntry? overlayEntry;
  bool s_wifi = false; //弹出层是否显示 （wifi 显示）
  String socp_wifi = "";
  @override
  void initState() {
    super.initState();
    _requestLocaitonPermission();

    updata(); //更新一次

    ///注册定位结果监听
    _locationListener = _locationPlugin
        .onLocationChanged()
        .listen((Map<String, Object> result) {
      setState(() {
        _locationResult = result;
        // print(_locationResult);
        if (_locationResult!.containsKey("latitude")) {
          lat = double.parse(_locationResult!["latitude"].toString());
          lon = double.parse(_locationResult!["longitude"].toString());
          final _markerPosition = LatLng(lat!, lon!);
          final Marker marker = Marker(
            position: _markerPosition,
            //使用默认hue的方式设置Marker的图标
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          );
          _markers["0"] = marker;
          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                  //中心点
                  target: mlat != null
                      ? LatLng((lat! + mlat!) / 2, (lon! + mlon!) / 2)
                      : LatLng(lat!, lon!),
                  //缩放级别
                  zoom: zoom,
                  //俯仰角0°~45°（垂直与地图时为0）
                  tilt: tilt,
                  //偏航角 0~360° (正北方为0)
                  bearing: 0),
            ),
            animated: true,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();

    ///移除定位监听
    if (null != _locationListener) {
      _locationListener?.cancel();
    }

    ///销毁定位
    _locationPlugin.destroy();
  }

  @override
  void reassemble() {
    super.reassemble();
    _requestLocaitonPermission();
  }

  void _requestLocaitonPermission() async {
    PermissionStatus status = await Permission.location.request();
    print('permissionStatus=====> $status');
  }

  ///设置定位参数
  void _setLocationOption() {
    AMapLocationOption locationOption = new AMapLocationOption();

    ///是否单次定位
    locationOption.onceLocation = false;

    ///是否需要返回逆地理信息
    locationOption.needAddress = true;

    ///逆地理信息的语言类型
    locationOption.geoLanguage = GeoLanguage.DEFAULT;
    locationOption.desiredLocationAccuracyAuthorizationMode =
        AMapLocationAccuracyAuthorizationMode.ReduceAccuracy;
    locationOption.fullAccuracyPurposeKey = "AMapLocationScene";

    ///设置Android端连续定位的定位间隔
    locationOption.locationInterval = 2000;

    ///设置Android端的定位模式<br>
    ///可选值：<br>
    ///<li>[AMapLocationMode.Battery_Saving]</li>
    ///<li>[AMapLocationMode.Device_Sensors]</li>
    ///<li>[AMapLocationMode.Hight_Accuracy]</li>
    locationOption.locationMode = AMapLocationMode.Hight_Accuracy;

    ///设置iOS端的定位最小更新距离<br>
    locationOption.distanceFilter = -1;

    ///设置iOS端期望的定位精度
    /// 可选值：<br>
    /// <li>[DesiredAccuracy.Best] 最高精度</li>
    /// <li>[DesiredAccuracy.BestForNavigation] 适用于导航场景的高精度 </li>
    /// <li>[DesiredAccuracy.NearestTenMeters] 10米 </li>
    /// <li>[DesiredAccuracy.Kilometer] 1000米</li>
    /// <li>[DesiredAccuracy.ThreeKilometers] 3000米</li>
    locationOption.desiredAccuracy = DesiredAccuracy.Best;

    ///设置iOS端是否允许系统暂停定位
    locationOption.pausesLocationUpdatesAutomatically = false;

    ///将定位参数设置给定位插件
    _locationPlugin.setLocationOption(locationOption);
  }

  ///开始定位
  void _startLocation() async {
    //开始定位之前设置定位参数
    bool isOpen = await LocationServiceCheck.checkLocationIsOpen;
    if (isOpen == false) {
      LocationServiceCheck.openLocationSetting();
      lo_time = Timer.periodic(const Duration(seconds: 10), (timer) async {
        bool isOpen = await LocationServiceCheck.checkLocationIsOpen;
        if (isOpen) {
          lo_time!.cancel();
          startlocat = true;
          _setLocationOption();
          _locationPlugin.startLocation();
        }
      });
    } else {
      startlocat = true;
      _setLocationOption();
      _locationPlugin.startLocation();
    }
  }

  ///停止定位
  void _stopLocation() {
    startlocat = false;
    _locationPlugin.stopLocation();
    setState(() {
      _markers.remove("0");
    });
  }

  void _onMapCreated(AMapController controller) {
    setState(() {
      _mapController = controller;
      printApprovalNumber();
    });
  }

  void _onCameraMoveEnd(CameraPosition cameraPosition) {
    zoom = cameraPosition.toMap()["zoom"];
    tilt = cameraPosition.toMap()["tilt"];
    print('_onCameraMoveEnd===> ${cameraPosition.toMap()}');
  }

  void printApprovalNumber() async {
    String mapContentApprovalNumber =
        (await _mapController?.getMapContentApprovalNumber())!;
    String satelliteImageApprovalNumber =
        (await _mapController?.getSatelliteImageApprovalNumber())!;
    print('地图审图号（普通地图）: $mapContentApprovalNumber');
    print('地图审图号（卫星地图): $satelliteImageApprovalNumber');
  }

//获取WIFI_GPS 数据
  void get_wifi_gps() async {
    final url_wifi = Uri.https(
        "iot-api.heclouds.com",
        "fuse-lbs/latest-wifi-location",
        {"product_id": "6FqaGR4PX6", "device_name": "m5311_gps"});
    var res = await http.get(
      url_wifi,
      headers: {
        "Authorization":
            "version=2022-05-01&res=userid%2F196883&et=2535782005&method=sha1&sign=fjfrucu%2BzzcZFk%2FgYGlp7w4jlJo%3D",
      },
    );
    if (res.statusCode == 200) {
      final wifidata = jsonDecode(res.body);
      print(wifidata["data"]);
      print(wifidata["data"]["lon"]);
      tim = wifidata["data"]["at"].toString();
      showmesg = mes + tim + "电量:" + vol.toString() + "V" + " WIFI";
      mlat = double.parse(wifidata["data"]["lat"].toString());
      mlon = double.parse(wifidata["data"]["lon"].toString());
      //坐标转换
      final url_wifi =
          Uri.https("restapi.amap.com", "v3/assistant/coordinate/convert", {
        "key": "b9a8f6068707e28c98ef60fff673a499",
        "locations": "${mlon},${mlat}",
        "coordsys": "gps"
      });
      final re = await http.get(
        url_wifi,
      );
      if (re.statusCode == 200) {
        print(re.body);
        final ree = jsonDecode(re.body);
        final t = ree["locations"].toString();
        mlon = double.parse(t.substring(0, t.indexOf(",")));
        mlat = double.parse(t.substring(t.indexOf(",") + 1));

        print(ree);
        final _markerPosition = LatLng(mlat!, mlon!);
        final Marker marker = Marker(
            position: _markerPosition,
            infoWindow: InfoWindow(snippet: "${tim}", title: "wifi"),
            //使用默认hue的方式设置Marker的图标
            icon: BitmapDescriptor.fromIconPath('assets/start.png'));
        setState(() {
          _markers["1"] = marker;
          if (startlocat == false) {
            _mapController?.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                    //中心点
                    target: LatLng(mlat!, mlon!),
                    //缩放级别
                    zoom: zoom,
                    //俯仰角0°~45°（垂直与地图时为0）
                    tilt: tilt,
                    //偏航角 0~360° (正北方为0)
                    bearing: 0),
              ),
              animated: true,
            );
          }
        });
      } else {
        print('Request failed with status: ${re.statusCode}.');
      }
    } else {
      print('Request failed with status: ${res.statusCode}.');
    }
  }

  void updata() async {
    var url_setdata = Uri.https(
      'iot-api.heclouds.com',
      'thingmodel/set-device-property',
    );
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6FqaGR4PX6\",\"device_name\":\"m5311_gps\",\"params\":{\"fun\":{\"updata\":1}}}");

    /*
    var url_setdata = Uri.https('openapi.heclouds.com', 'application',
        {"action": "SetDeviceProperty", "version": "1"});
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2022-05-01&res=userid%2F196883&et=2535782005&method=sha1&sign=fjfrucu%2BzzcZFk%2FgYGlp7w4jlJo%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6NudNI7L5R\",\"device_name\":\"ttty\",\"params\":{\"fun\":{\"real\":0,\"updata\":1,\"wifi\":0}}}");
    */
    if (response.statusCode == 200) {
      var d = jsonDecode(response.body);
      if (d["data"] == null && d["msg"] != "set property failed:acc timeout") {
        print(response.body);
        mes = d["msg"] + "\r\n";
      } else {
        mes = "";
      }
      gey();
    } else {
      print(response.body);
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void real() async {
    var url_setdata = Uri.https(
      'iot-api.heclouds.com',
      'thingmodel/set-device-property',
    );
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6FqaGR4PX6\",\"device_name\":\"m5311_gps\",\"params\":{\"fun\":{\"real\":1,\"updata\":0,\"wifi\":0}}}");

    if (response.statusCode == 200) {
      var d = jsonDecode(response.body);
      if (d["msg"] == "set property failed:device not online") {
        print(response.body);
        print('设备不在线,获取最近数据');
        mes = "设备不在线,获取最近数据    ";
      } else {
        mes = "";
        setState(() {
          real_timer = Timer.periodic(const Duration(seconds: 30), (timer) {
            gey();
          });
        });
      }
      gey();
    } else {
      print(response.body);
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void stopreal() async {
    var url_setdata = Uri.https(
      'iot-api.heclouds.com',
      'thingmodel/set-device-property',
    );
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6FqaGR4PX6\",\"device_name\":\"m5311_gps\",\"params\":{\"fun\":{\"real\":0,\"updata\":0,\"wifi\":0}}}");

    if (response.statusCode == 200) {
      var d = jsonDecode(response.body);
      if (d["msg"] == "set property failed:device not online") {
        print(response.body);
        print('设备不在线,获取最近数据');
        mes = "设备不在线";
      } else {
        mes = "";
      }
      real_timer!.cancel();
      setState(() {
        real_timer = null;
      });
    } else {
      print(response.body);
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void show_map() async {
    setState(() {
      show_w = !show_w;
      if (show_w) {
        s = 240;
      } else {
        s = 310;
      }
    });
    var url_setdata = Uri.https(
      'iot-api.heclouds.com',
      'thingmodel/set-device-property',
    );
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6FqaGR4PX6\",\"device_name\":\"m5311_gps\",\"params\":{\"fun\":{\"wifi\":${show_w ? "0" : "1"}}}}");

    if (response.statusCode == 200) {
      var d = jsonDecode(response.body);
      if (d["msg"] == "set property failed:device not online") {
        print(response.body);
        print('设备不在线,获取最近数据');
        mes = "设备不在线,获取最近数据";
      } else {
        mes = "";
      }
      // gey();
    } else {
      print(response.body);
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void gey() async {
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
      a.forEach(
        (element) async {
          // final d = jsonDecode(element);
          print(element["identifier"]);
          if (element["identifier"] == "gps") {
            tim =
                DateTime.fromMillisecondsSinceEpoch(element["time"]).toString();
            final da = jsonDecode(element["value"]);
            print(da["GPS"]);
            vol = (da["electricity"] ?? 0).toDouble();
            if (vol != 0) {
              vol = vol / 1000;
            }
            if (da["GPS"] == 0) {
              get_wifi_gps();
            } else {
              showmesg = mes + tim + "  电量:" + vol.toString() + "V" + " GPS";
              mlat = da["latitude"]; //3004.75047
              mlon = da["longitude"]; //12134.76341
              /****************计算gps 30度04.75047分 转化为 30.079307度*/
              int m = (mlat! / 100).floor();
              double a = double.parse((mlat.toString().substring(2)));
              a = a / 60;
              mlat = m + a;

              m = (mlon! / 100).floor();
              a = double.parse((mlon.toString().substring(3)));
              a = a / 60;
              mlon = m + a;
              /*********************************************************/
              print("malt:$mlat mlon:$mlon");
              //坐标转换
              final url_wifi = Uri.https(
                  "restapi.amap.com", "v3/assistant/coordinate/convert", {
                "key": "b9a8f6068707e28c98ef60fff673a499",
                "locations": "${mlon},${mlat}",
                "coordsys": "gps"
              });
              final re = await http.get(
                url_wifi,
              );
              if (re.statusCode == 200) {
                print(re.body);
                final ree = jsonDecode(re.body);
                final t = ree["locations"].toString();
                mlon = double.parse(t.substring(0, t.indexOf(",")));
                mlat = double.parse(t.substring(t.indexOf(",") + 1));

                print(ree);
                final _markerPosition = LatLng(mlat!, mlon!);
                final Marker marker = Marker(
                    position: _markerPosition,
                    infoWindow: InfoWindow(snippet: "${tim}", title: "gps"),
                    //使用默认hue的方式设置Marker的图标
                    icon: BitmapDescriptor.fromIconPath('assets/start.png'));
                setState(() {
                  _markers["1"] = marker;
                  if (startlocat == false) {
                    _mapController?.moveCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                            //中心点
                            target: LatLng(mlat!, mlon!),
                            //缩放级别
                            zoom: zoom,
                            //俯仰角0°~45°（垂直与地图时为0）
                            tilt: tilt,
                            //偏航角 0~360° (正北方为0)
                            bearing: 0),
                      ),
                      animated: true,
                    );
                  }
                });
              } else {
                print('Request failed with status: ${re.statusCode}.');
              }
            }
          }
          if (element["identifier"] == "w_name") {
            // tim =
            //     DateTime.fromMillisecondsSinceEpoch(element["time"]).toString();
            String wifida = element["value"];
            List<String> w = wifida.split(";");
            wifi_data1 = w[0];
            wifi_data2 = w[1];
            wifi_data3 = w[2];
            wifi_data4 = w[3];
            wifi_data5 = w[4];
            print(w);
          }
          if (element["identifier"] == "socpe") {
            final da = jsonDecode(element["value"]);
            socp_wifi = da["monitoring_wifi"] ?? "";
          }
        },
      );
      //print(a);
    } else {
      print('Request failed with status: ${response.statusCode}.');
      print(response.body);
    }
  }

  void set_wifi(String wifi_name) async {
    var url_setdata = Uri.https(
      'iot-api.heclouds.com',
      'thingmodel/set-device-property',
    );
    var response = await http.post(url_setdata,
        headers: {
          "Authorization":
              "version=2018-10-31&res=products%2F6FqaGR4PX6%2Fdevices%2Fm5311_gps&et=2535669105&method=md5&sign=u%2BiGRMuUhIy%2Fn632UST1ew%3D%3D",
          "Content-type": "application/json",
        },
        body:
            "{\"product_id\":\"6FqaGR4PX6\",\"device_name\":\"m5311_gps\",\"params\":{\"socpe\":{\"monitoring_wifi\":\"${wifi_name}\"}}}");

    if (response.statusCode == 200) {
      var d = jsonDecode(response.body);
      print(response.body);
      if (d["msg"] == "set property failed:device not online") {
        print(response.body);
        print('设备不在线,获取最近数据');
        mes = "设备不在线,获取最近数据   ";
      } else {
        mes = "";
      }
      gey();
    } else {
      print(response.body);
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void show_wifi() {
    overlayEntry = new OverlayEntry(builder: (context) {
      //外层使用Positioned进行定位，控制在Overlay中的位置
      return new Positioned(
          top: MediaQuery.of(context).size.height * 0.5,
          left: 60,
          right: 60,
          child: new Material(
            child: new Container(
              color: Color.fromARGB(200, 241, 239, 225),
              width: MediaQuery.of(context).size.width,
              //alignment: Alignment.center,
              child: Column(
                children: [
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      aState = setState;
                      return Container(
                        height: 200,
                        child: SingleChildScrollView(
                          child: Column(
                            children: accessPoints
                                .map((e) => Container(
                                      child: RadioListTile(
                                        groupValue: _wifiValue,
                                        value: "${e}",
                                        title: Text("${e}"),
                                        onChanged: (value) {
                                          setState(() {
                                            _wifiValue = value.toString();
                                            aState!(() {});
                                          });

                                          print(_wifiValue);
                                        },
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 5,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            s_wifi = false;
                          });
                          overlayEntry!.remove();
                        },
                        child: Text("关闭"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          set_wifi(_wifiValue);
                          setState(() {
                            s_wifi = false;
                          });
                          overlayEntry!.remove();
                        },
                        child: Text("确定"),
                      ),
                      Container(
                        width: 5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ));
    });
    setState(() {
      s_wifi = true;
    });
    //往Overlay中插入插入OverlayEntry
    Overlay.of(context).insert(overlayEntry!);
  }

  void _ScannedResults() async {
    bool isOpen = await LocationServiceCheck.checkLocationIsOpen;
    if (isOpen == false) {
      LocationServiceCheck.openLocationSetting();
    } else {
      // check platform support and necessary requirements
      final can =
          await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      switch (can) {
        case CanGetScannedResults.yes:
          final Points = await WiFiScan.instance.getScannedResults();
          Points.forEach((element) {
            if (!accessPoints.contains(element.ssid) && element.ssid != null) {
              accessPoints.add(element.ssid);
            }
          });
          show_wifi();

          // ...
          break;
        // ... handle other cases of CanGetScannedResults values
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AMapWidget amap = AMapWidget(
      apiKey: ConstConfig.amapApiKeys,
      privacyStatement: ConstConfig.amapPrivacyStatement,
      onMapCreated: _onMapCreated,
      markers: Set<Marker>.of(_markers.values),
      onCameraMoveEnd: _onCameraMoveEnd,
      // myLocationStyleOptions: MyLocationStyleOptions(
      //   true,
      //   circleFillColor: Colors.lightBlue,
      //   circleStrokeColor: Colors.blue,
      //   circleStrokeWidth: 1,
      // ),
    );
    // return Container(
    //   child: amap,
    // );
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: MediaQuery.of(context).size.height - s,
            width: MediaQuery.of(context).size.width,
            child: amap,
          ),
          Container(
            height: 5,
          ),
          Text("${showmesg}"),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                    onPressed: startlocat ? _stopLocation : _startLocation,
                    child: Text(startlocat ? "关闭我的" : "我的位置")),
                ElevatedButton(onPressed: updata, child: Text("更新")),
                ElevatedButton(
                    onPressed: real_timer == null ? real : stopreal,
                    child: Text(real_timer == null ? "实时更新" : "关闭更新")),
                ElevatedButton(
                    onPressed: show_map,
                    child: Text(show_w ? "显示WIFI" : "关闭显示")),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${socp_wifi == "" ? "没监控WiFi" : socp_wifi}"),
              Container(
                width: 20,
              ),
              ElevatedButton(
                  onPressed: s_wifi ? null : _ScannedResults,
                  child: Text("监控WiFi")),
            ],
          ),
          Offstage(
            offstage: show_w,
            child: Container(
              padding: EdgeInsets.only(left: 5, right: 5),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(wifi_data1),
                    Text(wifi_data2),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(wifi_data3),
                    Text(wifi_data4),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(wifi_data5),
                    Text(wifi_data6),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
