import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

// This file contains all the core logic for face recognition,
// separating it from the UI of the dashboard.

class FaceAuthService {
  Interpreter? _faceNetInterpreter;
  FaceDetector? _faceDetector;
  late Box _faceEmbeddingsBox;
  late CameraController _cameraController;

  static const int _modelInputSize = 112;
  static const double _similarityThreshold = 0.85;

  bool get isFaceRegistered => _faceEmbeddingsBox.containsKey('user_face_embedding');

  static Future<FaceAuthService> create() async {
    final service = FaceAuthService._();
    await service._initDependencies();
    return service;
  }

  FaceAuthService._();

  Future<void> _initDependencies() async {
    try {
      print('Initializing TFLite dependencies...');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found.');
      }

      _cameraController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await _cameraController.initialize();
      print('Camera initialized.');

      final appDocumentDirectory = await path_provider.getApplicationDocumentsDirectory();
      Hive.init(appDocumentDirectory.path);

      const secureStorage = FlutterSecureStorage();
      var encryptionKey = await secureStorage.read(key: 'hive_encryption_key');
      if (encryptionKey == null) {
        final key = Hive.generateSecureKey();
        encryptionKey = base64Url.encode(key);
        await secureStorage.write(key: 'hive_encryption_key', value: encryptionKey);
        print('Generated and stored new encryption key for Hive.');
      }

      final key = base64Url.decode(encryptionKey);
      _faceEmbeddingsBox = await Hive.openBox('face_embeddings', encryptionCipher: HiveAesCipher(key));
      print('Hive box opened with encryption.');

      _faceNetInterpreter = await Interpreter.fromAsset('assets/mobile_face_net.tflite');
      _faceDetector = FaceDetector(options: FaceDetectorOptions());
      print('TFLite and ML Kit dependencies loaded successfully!');
    } catch (e) {
      print('Failed to load dependencies: $e');
      rethrow;
    }
  }

  Future<Float32List?> _getFaceEmbeddingFromImage(XFile file, Rect faceRect) async {
    print('Starting embedding extraction...');
    if (_faceNetInterpreter == null) {
      print('Interpreter is null. Aborting.');
      return null;
    }

    final imageBytes = await file.readAsBytes();
    final img_lib.Image? capturedImage = img_lib.decodeImage(imageBytes);

    if (capturedImage == null) {
      print('Failed to decode captured image.');
      return null;
    }

    final img_lib.Image croppedFace = img_lib.copyCrop(
      capturedImage,
      x: faceRect.left.toInt(),
      y: faceRect.top.toInt(),
      width: faceRect.width.toInt(),
      height: faceRect.height.toInt(),
    );
    print('Face cropped to size: ${croppedFace.width}x${croppedFace.height}');

    final img_lib.Image resizedFace = img_lib.copyResize(
      croppedFace,
      width: _modelInputSize,
      height: _modelInputSize,
    );
    print('Face resized to model input size: ${resizedFace.width}x${resizedFace.height}');

    final input = Float32List(1 * _modelInputSize * _modelInputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < _modelInputSize; y++) {
      for (int x = 0; x < _modelInputSize; x++) {
        final img_lib.Pixel pixel = resizedFace.getPixel(x, y);
        final double r = pixel.r / 127.5 - 1.0;
        final double g = pixel.g / 127.5 - 1.0;
        final double b = pixel.b / 127.5 - 1.0;
        input[pixelIndex++] = r;
        input[pixelIndex++] = g;
        input[pixelIndex++] = b;
      }
    }
    print('Image converted to Float32List for model input.');

    final inputTensor = input.reshape([1, _modelInputSize, _modelInputSize, 3]);
    final output = Float32List(1 * 128).reshape([1, 128]);

    try {
      print('Running TFLite inference...');
      _faceNetInterpreter!.run(inputTensor, output);
      print('Inference successful. Returning embedding.');
      return Float32List.fromList(output[0].cast<double>());
    } catch (e) {
      print('Error during TFLite inference: $e');
      return null;
    }
  }

  double _cosineSimilarity(Float32List embedding1, Float32List embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length.');
    }
    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    if (norm1 == 0 || norm2 == 0) return 0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  Future<Map<String, dynamic>> registerFace() async {
    print('Registering face...');
    if (!_cameraController.value.isInitialized) {
      print('Camera not initialized.');
      return {'success': false, 'message': 'Camera not initialized.'};
    }

    final XFile? file = await _cameraController.takePicture();

    if (file == null) {
      print('Failed to capture image.');
      return {'success': false, 'message': 'Failed to capture image.'};
    }

    final inputImage = InputImage.fromFilePath(file.path);
    try {
      print('Detecting faces in captured image...');
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isNotEmpty) {
        print('Face detected.');
        final embedding = await _getFaceEmbeddingFromImage(file, faces.first.boundingBox);
        if (embedding != null) {
          _faceEmbeddingsBox.put('user_face_embedding', embedding.toList());
          print('Embedding stored successfully.');
          return {'success': true, 'message': 'Face registered successfully!'};
        } else {
          print('Failed to extract embedding.');
          return {'success': false, 'message': 'Failed to extract face embedding.'};
        }
      } else {
        print('No face detected.');
        return {'success': false, 'message': 'No face detected. Please try again.'};
      }
    } catch (e) {
      print('Error during registration: $e');
      return {'success': false, 'message': 'Failed to register face: $e'};
    }
  }

  Future<Map<String, dynamic>> authenticateFace() async {
    print('Starting face authentication...');
    final storedEmbedding = _faceEmbeddingsBox.get('user_face_embedding');
    if (storedEmbedding == null) {
      print('No face registered.');
      return {'success': false, 'message': 'Please register your face first.'};
    }
    final registeredFaceEmbedding = Float32List.fromList(storedEmbedding.cast<double>());

    if (!_cameraController.value.isInitialized) {
      print('Camera not initialized.');
      return {'success': false, 'message': 'Camera not initialized.'};
    }

    final XFile? file = await _cameraController.takePicture();
    if (file == null) {
      print('Failed to capture image.');
      return {'success': false, 'message': 'Failed to capture image.'};
    }

    final inputImage = InputImage.fromFilePath(file.path);
    try {
      print('Detecting faces for authentication...');
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isNotEmpty) {
        print('Face detected.');
        final currentEmbedding = await _getFaceEmbeddingFromImage(file, faces.first.boundingBox);
        if (currentEmbedding != null) {
          final double similarity = _cosineSimilarity(registeredFaceEmbedding, currentEmbedding);
          print('Cosine Similarity: ${similarity.toStringAsFixed(4)}');
          if (similarity >= _similarityThreshold) {
            print('Authentication successful!');
            return {'success': true, 'message': 'Face authenticated successfully! Similarity: ${similarity.toStringAsFixed(2)}'};
          } else {
            print('Authentication failed due to low similarity.');
            return {'success': false, 'message': 'Authentication Failed. Similarity: ${similarity.toStringAsFixed(2)}'};
          }
        } else {
          print('Failed to extract current embedding.');
          return {'success': false, 'message': 'Failed to extract face embedding.'};
        }
      } else {
        print('No face detected during authentication.');
        return {'success': false, 'message': 'No face detected for authentication. Please try again.'};
      }
    } catch (e) {
      print('Error during authentication: $e');
      return {'success': false, 'message': 'Failed to authenticate face: $e'};
    }
  }
}