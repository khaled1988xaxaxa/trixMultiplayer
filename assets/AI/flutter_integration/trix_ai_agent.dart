import 'dart:typed_data';
import 'package:pytorch_lite/pytorch_lite.dart';

class TrixAIAgent {
  late ModelObjectDetection _model;
  bool _isLoaded = false;
  
  // Model dimensions
  static const int STATE_SIZE = 186;
  static const int ACTION_SIZE = 52;
  
  // Load the AI model
  Future<void> loadModel() async {
    try {
      _model = await PytorchLite.loadObjectDetectionModel(
        "assets/models/trix_agent_model.pt",
        STATE_SIZE, ACTION_SIZE,
        objectDetectionModelType: ObjectDetectionModelType.yolov5,
      );
      _isLoaded = true;
      print("Trix AI Agent loaded successfully");
    } catch (e) {
      print("Error loading Trix AI Agent: $e");
    }
  }
  
  // Get AI move prediction
  Future<List<double>> predictMove(List<double> gameState) async {
    if (!_isLoaded) {
      throw Exception("Model not loaded. Call loadModel() first.");
    }
    
    try {
      // Ensure input is exactly 186 dimensions
      if (gameState.length != STATE_SIZE) {
        throw Exception("Game state must be exactly $STATE_SIZE dimensions");
      }
      
      // Convert to Float32List for the model
      Float32List input = Float32List.fromList(gameState);
      
      // Run inference
      var result = await _model.getImagePrediction(input);
      
      // Convert result to action probabilities
      return result.map((e) => e.toDouble()).toList();
    } catch (e) {
      print("Error during prediction: $e");
      return List.filled(ACTION_SIZE, 0.0); // Return neutral action if error
    }
  }
  
  // Get the best action index
  int getBestAction(List<double> actionProbabilities) {
    double maxProb = actionProbabilities[0];
    int bestAction = 0;
    
    for (int i = 1; i < actionProbabilities.length; i++) {
      if (actionProbabilities[i] > maxProb) {
        maxProb = actionProbabilities[i];
        bestAction = i;
      }
    }
    
    return bestAction;
  }
  
  // Get top N actions with probabilities
  List<Map<String, dynamic>> getTopActions(List<double> actionProbabilities, int topN) {
    List<Map<String, dynamic>> actions = [];
    
    for (int i = 0; i < actionProbabilities.length; i++) {
      actions.add({'action': i, 'probability': actionProbabilities[i]});
    }
    
    actions.sort((a, b) => b['probability'].compareTo(a['probability']));
    return actions.take(topN).toList();
  }
  
  // Dispose resources
  void dispose() {
    _isLoaded = false;
  }
}

// Usage example:
// final aiAgent = TrixAIAgent();
// await aiAgent.loadModel();
// List<double> gameState = getGameState(); // Your game state
// List<double> predictions = await aiAgent.predictMove(gameState);
// int bestMove = aiAgent.getBestAction(predictions);
// 
// // Or get top 3 moves:
// List<Map<String, dynamic>> topMoves = aiAgent.getTopActions(predictions, 3);
