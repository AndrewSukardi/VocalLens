import 'dart:io'; // Import untuk File manipulation
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Import flutter_tts
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(), // Menampilkan Splash Screen terlebih dahulu
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Delay 2 detik sebelum pindah ke CameraPermissionScreen
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraPermissionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set the background color
      body: Column(
        mainAxisAlignment: MainAxisAlignment
            .center, // This centers the column's children vertically
        children: [
          // Use an expanded widget to center the image vertically
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/icon/icon.png', // Path to your image in the assets folder
                width: 400, // You can adjust the width as needed
                height: 100, // You can adjust the height as needed
              ),
            ),
          ),

          // Use Align to position the text at the bottom
          Padding(
            padding: const EdgeInsets.only(
                bottom:
                    30.0), // Add padding if you want some space from the bottom
            child: const Text(
              "Vocal Lens",
              style: TextStyle(fontSize: 18), // Adjust text size as needed
            ),
          ),
        ],
      ),
    );
  }
}

class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  _CameraPermissionScreenState createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  FlutterTts _flutterTts = FlutterTts();
  List<String> _imagePaths = [];
  bool _isLoading = false; // Status loading untuk menampilkan spinner

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitializeCamera();
  }

  Future<void> _checkPermissionAndInitializeCamera() async {
    PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      await _initializeCamera();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Izin Tidak Diberikan'),
          content: Text('Camera diperlukan untuk menjalankan aplikasi'),
          actions: [
            TextButton(
              child: Text('KELUAR'),
              onPressed: () {
                Navigator.of(context).pop();
                exit(0);
              },
            ),
            TextButton(
              child: Text('COBA LAGI'),
              onPressed: () {
                Navigator.of(context).pop();
                _checkPermissionAndInitializeCamera();
              },
            ),
          ],
        );
      },
    );
  }

  void _takePicture() async {
    if (!_controller!.value.isInitialized) {
      return;
    }
    await _controller!.setFlashMode(FlashMode.auto);
    final raw_image = await _controller!.takePicture();
    print('Photo taken: ${raw_image.path}');

    // Tampilkan dialog preview dengan spinner sebelum resize dimulai
    setState(() {
      _isLoading = true; // Set loading status to true
    });
    _showImagePreviewDialog(raw_image.path);
    await Future.delayed(Duration(milliseconds: 500));

    // Proses resize gambar setelah dialog ditampilkan
    await _deleteOldImages();
    final image = await _resizeImage(raw_image.path, 255, 255);

    // Update state setelah resize selesai
    setState(() {
      _imagePaths.add(image.path);
      _isLoading = false; // Set loading status to false once done
    });

    String predictiontext = "aku suka kamu";
    print("Hasil Prediksi : $predictiontext");

    // Update dialog dengan gambar dan teks prediksi
    _updateImagePreviewDialog(image.path, predictiontext);

    // Ucapkan hasil prediksi
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.speak(predictiontext);
  }

  Future<File> _resizeImage(String imagePath, int width, int height) async {
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    final image = img.decodeImage(imageBytes)!;

    final resizedImage = img.copyResize(image, width: width, height: height);

    final resizedFilePath =
        '${file.parent.path}/resized_${file.uri.pathSegments.last}';
    final resizedFile = File(resizedFilePath)
      ..writeAsBytesSync(img.encodeJpg(resizedImage));

    print('Resized image saved to: $resizedFilePath');
    return resizedFile;
  }

  Future<void> _deleteOldImages() async {
    for (String path in _imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('Deleted old image: $path');
      }
    }
    _imagePaths.clear();
  }

  // Fungsi untuk menampilkan dialog dengan spinner
  void _showImagePreviewDialog(String imagePath, [String? kata]) {
    const String waiting = "Melakukan Prediksi Gambar";
    String displayText = kata ?? 'Gagal Melakukan Prediksi Gambar';
    showDialog(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(
            child: Text(
              'Prediksi',
              style: TextStyle(fontSize: 20),
            ),
          ),
          content: Scrollbar(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isLoading) ...[
                    CircularProgressIndicator(),
                    const SizedBox(
                        height: 10), // Add some space below the spinner
                    Text(
                      waiting, // Text under the spinner
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      height: 200,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      displayText,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _flutterTts.speak(displayText);
                          },
                          child: const Text(
                            "Replay",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Fungsi untuk memperbarui dialog setelah resize selesai
  void _updateImagePreviewDialog(String imagePath, [String? kata]) {
    Navigator.of(context, rootNavigator: true)
        .pop(); // Close the previous dialog

    // Show the updated dialog with the resized image and prediction
    _showImagePreviewDialog(imagePath, kata);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? GestureDetector(
              onTap: _takePicture,
              child: SizedBox.expand(
                child: CameraPreview(_controller!),
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Menunggu Camera"),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
