import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int? _temperature;
  int? _humidity;

  @override
  initState() {
    super.initState();
    connectAws();
  }

  Future<int> connectAws() async {
    // Your AWS IoT Core endpoint url
    print("hola xd");
    const url = 'a1ugah3gemg9dt-ats.iot.us-west-2.amazonaws.com';
    // AWS IoT MQTT default port
    const port = 8883;
    // The client id unique to your device
    const clientId = 'app_flutter';

    // Create the client
    final client = MqttServerClient.withPort(url, clientId, port);

    // Set secure
    client.secure = true;
    // Set Keep-Alive
    client.keepAlivePeriod = 20;
    // Set the protocol to V3.1.1 for AWS IoT Core, if you fail to do this you will not receive a connect ack with the response code
    client.setProtocolV311();
    // logging if you wish
    client.logging(on: false);
    print("paso 2");
    // Set the security context as you need, note this is the standard Dart SecurityContext class.
    // If this is incorrect the TLS handshake will abort and a Handshake exception will be raised,
    // no connect ack message will be received and the broker will disconnect.
    // For AWS IoT Core, we need to set the AWS Root CA, device cert & device private key
    // Note that for Flutter users the parameters above can be set in byte format rather than file paths
    final context = SecurityContext.defaultContext;
    ByteData rootCa = await rootBundle.load('assets/certs/AmazonRootCA1.pem');
    ByteData privateKey = await rootBundle.load(
        'assets/certs/8a16158fe9fa767e45b9cd649866cd808e40ae769085bc7a2257b42e001f2ff5-private.pem.key');
    ByteData certificate = await rootBundle.load(
        'assets/certs/8a16158fe9fa767e45b9cd649866cd808e40ae769085bc7a2257b42e001f2ff5-certificate.pem.crt');

    context.setTrustedCertificatesBytes(rootCa.buffer.asUint8List());
    context.useCertificateChainBytes(certificate.buffer.asUint8List());
    context.usePrivateKeyBytes(privateKey.buffer.asUint8List());
    client.securityContext = context;
    // Setup the connection Message
    final connMess =
        MqttConnectMessage().withClientIdentifier('app_flutter').startClean();
    client.connectionMessage = connMess;

    // Connect the client
    try {
      print('MQTT client connecting to AWS IoT using certificates....');
      await client.connect();
    } on Exception catch (e) {
      print('MQTT client exception - $e');
      client.disconnect();
      exit(-1);
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT client connected to AWS IoT');

      // Publish to a topic of your choice after a slight delay, AWS seems to need this
      await MqttUtilities.asyncSleep(1);
      const topic = '/test/topic';
      final builder = MqttClientPayloadBuilder();
      builder.addString('Hello World');
      // Important: AWS IoT Core can only handle QOS of 0 or 1. QOS 2 (exactlyOnce) will fail!
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      // Subscribe to the same topic
      client.subscribe('temperature', MqttQos.atLeastOnce);
      client.subscribe('humidity', MqttQos.atLeastOnce);
      // Print incoming messages from another client on this topic
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print(c);
        if (c[0].topic == 'temperature') {
          print("Mensaje recibido en temperatura");
          setState(() {
            _temperature = int.parse(pt);
          });
        } else if (c[0].topic == 'humidity') {
          print("Mensaje recibido en humedad");
          setState(() {
            _humidity = int.parse(pt);
          });
        }
        print(
            'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
        print('');
      });
    } else {
      print(
          'ERROR MQTT client connection failed - disconnecting, state is ${client.connectionStatus!.state}');
      client.disconnect();
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MQTT app remedial',
        home: Scaffold(
          backgroundColor: const Color(0xFF2C3333),
          body: SingleChildScrollView(
            child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50,
                    ),
                    Container(
                      alignment: Alignment.center,
                      child: const Text(
                        "Temperatura",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Roboto',
                            fontSize: 30,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    Container(
                      alignment: Alignment.center,
                      child: Card(
                        color: Color.fromRGBO(46, 79, 79, 1),
                        elevation: 10,
                        child: Container(
                          width: 300,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(10),
                          child: Column(children: [
                            Container(
                                alignment: Alignment.centerLeft,
                                child: const Image(
                                  image: AssetImage('assets/images/cloud.png'),
                                  width: 40,
                                  height: 36,
                                )),
                            if (_temperature == null)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "No hay datos aun",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 30,
                                  ),
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "$_temperature°C",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 30,
                                  ),
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                'En algún lugar de la UT...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic),
                              ),
                            )
                          ]),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 50),
                      alignment: Alignment.center,
                      child: const Text(
                        "Humedad",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Roboto',
                            fontSize: 30,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 30,
                    ),
                    Container(
                      alignment: Alignment.center,
                      child: Card(
                        color: Color.fromRGBO(46, 79, 79, 1),
                        elevation: 10,
                        child: Container(
                          width: 300,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(10),
                          child: Column(children: [
                            Container(
                                alignment: Alignment.centerLeft,
                                child: const Image(
                                  image:
                                      AssetImage('assets/images/humidity.png'),
                                  width: 40,
                                  height: 36,
                                )),
                            if (_humidity == null)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "No hay datos aun",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 30,
                                  ),
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "$_humidity%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 30,
                                  ),
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                'En algún lugar de la UT...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic),
                              ),
                            )
                          ]),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 60),
                      alignment: Alignment.bottomCenter,
                      child: const Image(
                        image: AssetImage('assets/images/brands.png'),
                        width: 300,
                        height: 70,
                      ),
                    )
                  ],
                )),
          ),
        ));
  }
}
