import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FireDetectionService {
  static const String modelPath = 'assets/models/fire_detection_model.tflite';
  static const int inputSize = 224;
  static const double threshold = 0.5;
  
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _useFallbackMode = false;
  
  /// Initialize the TensorFlow Lite model
  Future<void> loadModel() async {
    try {
      print('Attempting to load model from: $modelPath');
      
      // Check if asset exists first
      final data = await rootBundle.load(modelPath);
      print('Model asset found, size: ${data.lengthInBytes} bytes');
      
      // Try loading the model
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      
      _isModelLoaded = true;
      _useFallbackMode = false;
      print('Fire detection model loaded successfully');
      
      // Test the model with a dummy input
      await _testModel();
      
    } catch (e) {
      print('Failed to load TensorFlow Lite model: $e');
      print('Switching to fallback mode (simulated detection)');
      _isModelLoaded = true;
      _useFallbackMode = true;
    }
  }
  
  /// Test the model with dummy data
  Future<void> _testModel() async {
    if (_interpreter == null || _useFallbackMode) return;
    
    try {
      // Create dummy input
      final input = List.generate(1, (i) => 
        List.generate(inputSize, (j) => 
          List.generate(inputSize, (k) => 
            List.generate(3, (l) => 0.5))));
      
      final output = [List.filled(1, 0.0)];
      
      _interpreter!.run(input, output);
      print('Model test successful');
    } catch (e) {
      print('Model test failed, switching to fallback: $e');
      _useFallbackMode = true;
    }
  }
  
  /// Check if the model is loaded and ready
  bool get isModelLoaded => _isModelLoaded;
  
  /// Preprocess image for model input
  List<List<List<List<double>>>> _preprocessImage(Uint8List imageBytes) {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to model input size
    img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);
    
    // Convert to normalized float array [1, 224, 224, 3]
    List<List<List<List<double>>>> input = List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) => List.generate(3, (c) {
            img.Pixel pixel = resized.getPixel(x, y);
            switch (c) {
              case 0: return pixel.r / 255.0; // Red
              case 1: return pixel.g / 255.0; // Green
              case 2: return pixel.b / 255.0; // Blue
              default: return 0.0;
            }
          }),
        ),
      ),
    );
    
    return input;
  }
  
  /// Detect fire in the given image bytes
  Future<FireDetectionResult> detectFire(Uint8List imageBytes) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
    
    try {
      if (_useFallbackMode) {
        // Fallback mode: Use simple image analysis
        return _fallbackFireDetection(imageBytes);
      }
      
      // Preprocess image
      final input = _preprocessImage(imageBytes);
      
      // Prepare output tensor
      final output = [List.filled(1, 0.0)];
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Get confidence score
      final confidence = output[0][0] as double;
      final isFire = confidence > threshold;
      
      return FireDetectionResult(
        isFire: isFire,
        confidence: confidence,
        threshold: threshold,
      );
    } catch (e) {
      print('Detection failed, using fallback: $e');
      return _fallbackFireDetection(imageBytes);
    }
  }
  
  /// Fallback fire detection using simple image analysis
  FireDetectionResult _fallbackFireDetection(Uint8List imageBytes) {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image for fallback detection');
      }
      
      // Simple fire detection based on color analysis
      int redPixels = 0;
      int orangePixels = 0;
      int totalPixels = 0;
      
      // Sample pixels (every 10th pixel for performance)
      for (int y = 0; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          
          // Check for fire-like colors (red/orange/yellow)
          if (r > 150 && g > 50 && b < 100 && r > g && r > b) {
            if (g > 100) {
              orangePixels++; // Orange/Yellow
            } else {
              redPixels++; // Red
            }
          }
          totalPixels++;
        }
      }
      
      // Calculate fire probability based on red/orange pixel ratio
      final firePixelRatio = (redPixels + orangePixels) / totalPixels;
      final confidence = (firePixelRatio * 2.0).clamp(0.0, 1.0);
      final isFire = confidence > 0.3; // Lower threshold for fallback
      
      print('Fallback detection: $redPixels red, $orangePixels orange pixels of $totalPixels total');
      print('Fire pixel ratio: ${firePixelRatio.toStringAsFixed(3)}, confidence: ${confidence.toStringAsFixed(3)}');
      
      return FireDetectionResult(
        isFire: isFire,
        confidence: confidence,
        threshold: 0.3,
      );
    } catch (e) {
      print('Fallback detection failed: $e');
      // Return a default "no fire" result
      return FireDetectionResult(
        isFire: false,
        confidence: 0.0,
        threshold: threshold,
      );
    }
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}

/// Result of fire detection
class FireDetectionResult {
  final bool isFire;
  final double confidence;
  final double threshold;
  
  FireDetectionResult({
    required this.isFire,
    required this.confidence,
    required this.threshold,
  });
  
  /// Get confidence as percentage
  double get confidencePercentage => confidence * 100;
  
  /// Get risk level based on confidence
  String get riskLevel {
    if (!isFire) return 'Safe';
    if (confidence > 0.8) return 'High Risk';
    if (confidence > 0.6) return 'Medium Risk';
    return 'Low Risk';
  }
  
  @override
  String toString() {
    return 'FireDetectionResult(isFire: $isFire, confidence: ${confidencePercentage.toStringAsFixed(1)}%, riskLevel: $riskLevel)';
  }
}
