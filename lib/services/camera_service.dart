import 'dart:typed_data';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  
  /// Initialize camera service
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      // Use back camera by default
      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      _isInitialized = true;
      
      print('Camera initialized successfully');
    } catch (e) {
      print('Failed to initialize camera: $e');
      throw e;
    }
  }
  
  /// Get camera controller
  CameraController? get controller => _controller;
  
  /// Check if camera is initialized
  bool get isInitialized => _isInitialized && _controller != null;
  
  /// Capture image and return as bytes
  Future<Uint8List> captureImage() async {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }
    
    try {
      final XFile image = await _controller!.takePicture();
      return await image.readAsBytes();
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }
  
  /// Start image stream for real-time detection
  void startImageStream(Function(CameraImage) onImage) {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }
    
    _controller!.startImageStream(onImage);
  }
  
  /// Stop image stream
  void stopImageStream() {
    if (isInitialized) {
      _controller!.stopImageStream();
    }
  }
  
  /// Convert CameraImage to Uint8List (JPEG format)
  static Future<Uint8List> convertCameraImage(CameraImage image) async {
    try {
      // This is a simplified conversion - you might need to adjust based on your needs
      final bytes = image.planes[0].bytes;
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to convert camera image: $e');
    }
  }
  
  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    
    final currentCamera = _controller?.description;
    final newCamera = _cameras.firstWhere(
      (camera) => camera != currentCamera,
      orElse: () => _cameras.first,
    );
    
    await _controller?.dispose();
    
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    
    await _controller!.initialize();
  }
  
  /// Toggle flash
  Future<void> toggleFlash() async {
    if (!isInitialized) return;
    
    final flashMode = _controller!.value.flashMode;
    final newFlashMode = flashMode == FlashMode.off 
        ? FlashMode.torch 
        : FlashMode.off;
    
    await _controller!.setFlashMode(newFlashMode);
  }
  
  /// Dispose camera resources
  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}
