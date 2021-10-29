import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'image_painter/src/_paint_over_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(ExampleApp());
}

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Painter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ImagePainterExample(),
    );
  }
}

class ImagePainterExample extends StatefulWidget {
  @override
  _ImagePainterExampleState createState() => _ImagePainterExampleState();
}

class _ImagePainterExampleState extends State<ImagePainterExample> {
  final _imageKey = GlobalKey<ImagePainterState>();
  final _key = GlobalKey<ScaffoldState>();

  Future<void> saveImage() async {
    final image = _imageKey.currentState!.storePaintHistory();
    List paintHistory = [];
    image.forEach((element) {
      paintHistory.add(element.toJson());
    });
    await GetStorage().write('image', paintHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: AppBar(
        title: const Text("Image Painter Example"),
        actions: [
          IconButton(
            icon: const Icon(Icons.ac_unit),
            onPressed: saveImage,
          ),
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () {
              setState(() {
                _imageKey.currentState!.loadHistory();
              });
            },
          )
        ],
      ),
      body: Center(
        child: Stack(
          children: [
            Image.network(
                "https://static.remove.bg/remove-bg-web/c1cb70eda3ebeb16163b58bd003f6ad1544ece99/assets/start-1abfb4fe2980eabfbbaaa4365a0692539f7cd2725f324f904565a9a744f8e214.jpg"),
            ImagePainter.signature(
              height: 217,
              signatureBgColor: Colors.transparent,
              width: 500,
              initialStrokeWidth: 2,
              initialPaintMode: PaintMode.line,
              key: _imageKey,
            ),
          ],
        ),
      ),
    );
  }
}
