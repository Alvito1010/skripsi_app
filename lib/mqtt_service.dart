import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class MQTTService {
  late MqttServerClient client;
  String statusText = "Disconnected";
  String receivedMessage = "";
  final String topic = '\$aws/things/memilah-1/shadow/name/memilah-1/update';

  Future<List<String>> loadCertificates() async {
    final List<String> certificates = [];
    certificates.add(await rootBundle.loadString('assets/AmazonRootCA1.pem'));
    certificates.add(await rootBundle.loadString('assets/Certificate.pem.crt'));
    certificates.add(await rootBundle.loadString('assets/Private Key for IoT Core.key'));
    return certificates;
  }

  Future<void> connect(
    List<String> certificates, 
    void Function() onConnected, 
    void Function() onDisconnected, 
    void Function(String) onSubscribed, 
    void Function(String) onSubscribeFail, 
    void Function(String?) onUnsubscribed, 
    void Function() pong, 
    void Function(String, String) onMessageReceived
  ) async {
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
      print('Connected');

      // Setup updates listener
      if (client.updates != null) {
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
          if (c != null && c.isNotEmpty) {
            final recMessage = c[0].payload as MqttPublishMessage;
            final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
            final topic = c[0].topic;
            print('Received message: $payload on topic: $topic');
            onMessageReceived(payload, topic);
          } else {
            print('No message received in the update stream');
          }
        });
      } else {
        print('Client updates stream is null');
      }

      subscribe(); // Subscribe to the topic after connecting
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }
  }

  void connectAndHandle(List<String> certificates, 
    void Function() onConnected, 
    void Function() onDisconnected, 
    void Function(String) onSubscribed, 
    void Function(String) onSubscribeFail, 
    void Function(String?) onUnsubscribed, 
    void Function() pong, 
    void Function(String, String) onMessageReceived
  ) async {
    await connect(certificates, onConnected, onDisconnected, onSubscribed, onSubscribeFail, onUnsubscribed, pong, onMessageReceived);
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
    } else {
      print('Client is already disconnected.');
    }
  }
}
