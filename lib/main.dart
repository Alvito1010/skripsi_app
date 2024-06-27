import 'dart:convert'; // Import JSON decode
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hexcolor/hexcolor.dart';
import 'dart:async'; // Import Timer

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MQTTExample(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MQTTExample extends StatefulWidget {
  @override
  _MQTTExampleState createState() => _MQTTExampleState();
}

class _MQTTExampleState extends State<MQTTExample> {
  late MqttServerClient client;
  String statusText = "Disconnected";
  String receivedMessage = "";
  final String topic = '\$aws/things/memilah-1/shadow/name/memilah-1/update';
  double progressValuePlastic = 0.00;
  double progressValuePaper = 0.00;
  double progressValueCan = 0.0;
  String blueSwoopImg = "assets/images/blueSwoop.png";
  String redSwoopImg = "assets/images/redSwoop.png";
  String orangSwoopImg = "assets/images/orangeSwoop.png";
  int binHeight = 45;
  Color paperProgress = HexColor("#f8b96c");
  Color plasticProgress = HexColor("#59c7f3");
  Color canProgress = HexColor("#e17070");
  Color paperText = HexColor("#df783b");
  Color plasticText= HexColor("#266ba7");
  Color canText = HexColor("#a70000");
  Timer? _timer;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Load certificate files
    loadCertificates().then((certs) async {
      await connect(certs); // Connect to MQTT broker with loaded certificates
    });
  }

  Future<List<String>> loadCertificates() async {
    final List<String> certificates = [];
    certificates.add(await rootBundle.loadString('assets/AmazonRootCA1.pem'));
    certificates.add(await rootBundle.loadString('assets/Certificate.pem.crt'));
    certificates.add(
        await rootBundle.loadString('assets/Private Key for IoT Core.key'));
    return certificates;
  }

  Future<void> connect(List<String> certificates) async {
    // Create MQTT client
    client = MqttServerClient.withPort(
        'a3d6ocbe64cfcw-ats.iot.ap-southeast-1.amazonaws.com',
        'flutter_skripsi_client',
        8883);
    client.logging(on: true);
    client.keepAlivePeriod = 300;

    client.secure = true;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onUnsubscribed = onUnsubscribed;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;

    try {
      print('Connecting');
      final securityContext = SecurityContext.defaultContext;
      securityContext.setTrustedCertificatesBytes(certificates[0].codeUnits);
      securityContext.useCertificateChainBytes(certificates[1].codeUnits);
      securityContext.usePrivateKeyBytes(certificates[2].codeUnits);
      client.securityContext = securityContext;

      await client.connect();
      setState(() {
        statusText = 'Connected';
      });
      print('Connected');

      // Setup updates listener
      if (client.updates != null) {
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
          if (c != null && c.isNotEmpty && !isUpdating) {
            final recMessage = c[0].payload as MqttPublishMessage;
            final payload = MqttPublishPayload.bytesToStringAsString(
                recMessage.payload.message);
            final topic = c[0].topic;
            print('Received message: $payload on topic: $topic');
            setState(() {
              receivedMessage = payload;
            });
          } else {
            print('No message received in the update stream');
          }
        });
      } else {
        print('Client updates stream is null');
      }

      // Start a timer to update values every 10 seconds
      _timer = Timer.periodic(Duration(seconds: 3), (timer) {
        updateValues();
      });

      subscribe(); // Subscribe to the topic after connecting
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
      setState(() {
        statusText = 'Disconnected';
      });
    }
  }

  void updateValues() {
    if (receivedMessage.isNotEmpty) {
      setState(() {
        try {
          isUpdating = true;
          final Map<String, dynamic> data =
              jsonDecode(receivedMessage); // Parse JSON
          final double plastic = (data['plastic'] as num).toDouble();
          final double paper = (data['paper'] as num).toDouble();
          final double can = (data['can'] as num).toDouble();

          // Calculate the percentage filled
          final double plasticPercentage = ((binHeight - plastic) / binHeight) * 100;
          final double paperPercentage = ((binHeight - paper) / binHeight) * 100;
          final double canPercentage = ((binHeight - can) / binHeight) * 100;

          if (plastic >= 0 &&
              plastic <= 100 &&
              paper >= 0 &&
              paper <= 100 &&
              can >= 0 &&
              can <= 100) {
            progressValuePlastic = (plasticPercentage.clamp(0, 100)) / 100;
            progressValuePaper = (paperPercentage.clamp(0, 100)) / 100;
            progressValueCan = (canPercentage.clamp(0, 100)) / 100;
            print(
                'State updated: Plastic - $progressValuePlastic, Paper - $progressValuePaper, Can - $progressValueCan');
          } else {
            print('Received value out of range: $receivedMessage');
          }
        } catch (e) {
          print('Error parsing received message: $receivedMessage, error: $e');
        } finally {
          isUpdating = false;
        }
      });
    }
  }

  void onConnected() {
    setState(() {
      statusText = 'Connected';
    });
    print('Connected');
  }

  void onDisconnected() {
    _timer?.cancel();
    setState(() {
      statusText = 'Disconnected';
    });
    print('Disconnected');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  void onSubscribeFail(String topic) {
    print('Failed to subscribe to topic: $topic');
  }

  void onUnsubscribed(String? topic) {
    print('Unsubscribed from topic: $topic');
  }

  void pong() {
    print('Ping response client callback invoked');
  }

  void subscribe() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Subscribing to topic $topic');
      client.subscribe(topic, MqttQos.atLeastOnce);
    } else {
      print('Client is not connected. Unable to subscribe.');
    }
  }

  void unsubscribe() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Unsubscribing from topic $topic');
      client.unsubscribe(topic);
    } else {
      print('Client is not connected. Unable to unsubscribe.');
    }
  }

  void disconnect() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Disconnecting');
      client.disconnect();
      _timer?.cancel();
      setState(() {
        statusText = 'Disconnected';
      });
    } else {
      print('Client is already disconnected.');
    }
  }

  void connectAndHandle(List<String> certs) async {
    await connect(certs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/Union.png',
              fit: BoxFit.cover,
              height: MediaQuery.of(context).size.height / 3,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height /
                13, // Adjust the position of the text
            left: 26,
            right: 0,
            child: Text(
              'Memilah\nSmart Bin Monitoring',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                fontSize: 50,
                fontWeight: FontWeight.bold,
                height: 1.2,
                letterSpacing: -1,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/memilahLogoBottomLeft.png',
              width: MediaQuery.of(context).size.width / 1.8,
              height: MediaQuery.of(context).size.width / 1.3,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.275),
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.05,
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusText == "Connected"
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02,)
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03,),
                  Row(
                    children: [
                      Spacer(),
                      Column(
                        children: [
                          ProgressBar(
                            progress: progressValuePaper,
                            color: paperProgress,
                            imgName: orangSwoopImg,
                            label: 'Paper',
                            textColor: paperText,
                          ),
                        ],
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.07,),
                      Column(
                        children: [
                          ProgressBar(
                            progress: progressValuePlastic,
                            color: plasticProgress,
                            imgName: blueSwoopImg,
                            label: 'Plastic',
                            textColor: plasticText,
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Row(
                    children: [
                      Spacer(),
                      Column(
                        children: [
                          ProgressBar(
                            progress: progressValueCan,
                            color: canProgress,
                            imgName: redSwoopImg,
                            label: 'Can',
                            textColor: canText,
                          ),
                        ],
                      ),
                      Spacer(),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.43,
                      ),
                      Spacer()
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          loadCertificates().then((certs) {
                            connectAndHandle(certs);
                          });
                        },
                        child: Text('Connect'),
                      ),
                      Spacer(),
                      ElevatedButton(
                        onPressed: disconnect,
                        child: Text('Disconnect'),
                      ),
                      Spacer()
                    ],
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String imgName;
  final String label;
  final Color textColor;

  const ProgressBar({
    Key? key,
    required this.progress,
    required this.color,
    required this.imgName,
    required this.label,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withOpacity(0.5), // Background color with lower opacity
            ),
            child: Stack(
              alignment: AlignmentDirectional.bottomStart, // Align children to bottom
              children: [
                FractionallySizedBox(
                  heightFactor: progress,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      gradient: LinearGradient(
                          colors: [color.withOpacity(0.0), color.withOpacity(1.0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Image.asset(
                    imgName,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: MediaQuery.of(context).size.height * 0.25,
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.1,
                  left: MediaQuery.of(context).size.width * 0.02,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 42,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.02,
                  left: MediaQuery.of(context).size.width * 0.02,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
