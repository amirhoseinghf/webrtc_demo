import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();
  final sdpController = TextEditingController();
  String? offer;
  String? answer;
  bool _offer = false;
  List<String> candidates = [];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  initRenderer() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    MediaStream stream =
    await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _localVideoRenderer.srcObject = stream;
    return stream;
  }

  _createPeerConnecion() async {
    Map<String, dynamic> configuration = {
      "sdpSemantics": "plan-b",
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
    await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex,
        }));
        candidates.add(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex,
        }));
        setState(() {

        });
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteVideoRenderer.srcObject = stream;
    };

    return pc;
  }

  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    log(json.encode(session));
    _offer = true;

    _peerConnection!.setLocalDescription(description);
    setState(() {
      offer = json.encode(session);
    });
  }

  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));

    _peerConnection!.setLocalDescription(description);
    answer = json.encode(session);
    setState(() {

    });
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);

    String sdp = write(session, null);

    RTCSessionDescription description =
    RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    // print("remoteDescription: " + description.toMap());

    await _peerConnection!.setRemoteDescription(description);
  }

  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    log("canadadidate: " + session['candidate']);
    dynamic candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
    setState(() {

    });
  }

  @override
  void initState() {
    initRenderer();
    _createPeerConnecion().then((pc) {
      _peerConnection = pc;
    });
    Future.delayed(Duration(seconds: 1)).then((value) {
      (context as Element).reassemble();
    });
    super.initState();
  }

  @override
  void dispose() async {
    await _localVideoRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  SizedBox videoRenderers() => SizedBox(
    height: 210,
    child: Row(children: [
      Flexible(
        child: Container(
          key: const Key('local'),
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
          decoration: const BoxDecoration(color: Colors.black),
          child: RTCVideoView(_localVideoRenderer),
        ),
      ),
      Flexible(
        child: Container(
          key: const Key('remote'),
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
          decoration: const BoxDecoration(color: Colors.black),
          child: RTCVideoView(_remoteVideoRenderer, mirror: true,),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              videoRenderers(),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: TextField(
                        controller: sdpController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                        maxLength: TextField.noMaxLength,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _createOffer,
                        child: const Text("Offer"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      ElevatedButton(
                        onPressed: _createAnswer,
                        child: const Text("Answer"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      ElevatedButton(
                        onPressed: _setRemoteDescription,
                        child: const Text("Set Remote Description"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      ElevatedButton(
                        onPressed: _addCandidate,
                        child: const Text("Set Candidate"),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 50,),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SelectableText(
                  offer != null ? offer! : answer != null ? answer! : 'nil'
                ),
              ),
              const SizedBox(height: 10,),
              Container(
                height: 5,
                width: 400,
                color: Colors.blue,
              ),
              Container(
                height: 700,
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (ctx, index) => SelectableText(candidates[index]),
                ),
              )

            ],
          ),
        ));
  }
}