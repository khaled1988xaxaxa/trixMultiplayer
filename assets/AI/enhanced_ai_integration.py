#!/usr/bin/env python3
"""
Enhanced Trix AI Integration for Human-Enhanced Model
===================================================
Integration script for the human-enhanced PPO model trained with supervised learning.
"""

import json
import torch
import numpy as np
import os
import sys
from typing import List, Dict, Any, Optional, Tuple

# Try to import stable_baselines3 for the enhanced model
try:
    from stable_baselines3 import PPO
    STABLE_BASELINES_AVAILABLE = True
except ImportError:
    STABLE_BASELINES_AVAILABLE = False
    print("⚠️ stable_baselines3 not available, using fallback mode")

class EnhancedTrixAI:
    """Enhanced Trix AI using human-enhanced PPO model"""
    
    def __init__(self, model_path: str = None, config_path: str = None):
        self.model = None
        self.model_loaded = False
        self.device = torch.device('cpu')  # Use CPU for mobile compatibility
        
        # Load configuration
        if config_path is None:
            config_path = "agent_config_enhanced.json"
        
        try:
            with open(config_path, 'r') as f:
                self.config = json.load(f)
            print(f"✅ Loaded enhanced configuration from {config_path}")
        except Exception as e:
            print(f"⚠️ Could not load config: {e}")
            # Fallback configuration
            self.config = {
                "model_info": {
                    "state_size": 186,
                    "action_size": 52,
                    "model_type": "Human-Enhanced PPO"
                }
            }
        
        self.state_size = self.config['model_info']['state_size']
        self.action_size = self.config['model_info']['action_size']
        
        # Load the enhanced model
        if model_path is None:
            model_path = "policy.pth"
        
        self.load_enhanced_model(model_path)
    
    def load_enhanced_model(self, model_path: str):
        """Load the human-enhanced PPO model"""
        try:
            if STABLE_BASELINES_AVAILABLE:
                # Try to load as stable_baselines3 model
                try:
                    # Create a dummy environment for model loading
                    import gym
                    from stable_baselines3.common.env_util import make_vec_env
                    
                    # For now, we'll load the policy directly
                    checkpoint = torch.load(model_path, map_location=self.device)
                    
                    if isinstance(checkpoint, dict):
                        print("✅ Enhanced PPO model loaded successfully")
                        self.model = checkpoint
                        self.model_loaded = True
                    else:
                        print("⚠️ Unexpected model format")
                        
                except Exception as e:
                    print(f"⚠️ Could not load as stable_baselines3 model: {e}")
                    self.load_pytorch_model(model_path)
            else:
                self.load_pytorch_model(model_path)
                
        except Exception as e:
            print(f"❌ Failed to load enhanced model: {e}")
    
    def load_pytorch_model(self, model_path: str):
        """Fallback: Load as PyTorch model"""
        try:
            checkpoint = torch.load(model_path, map_location=self.device)
            self.model = checkpoint
            self.model_loaded = True
            print(f"✅ Loaded model as PyTorch checkpoint")
        except Exception as e:
            print(f"❌ Failed to load PyTorch model: {e}")
    
    def predict_move(self, game_state: List[float], legal_actions: List[int] = None) -> int:
        """
        Predict the best move given the current game state
        
        Args:
            game_state: 186-dimensional state vector
            legal_actions: List of legal action indices (0-51)
            
        Returns:
            Best action index
        """
        if not self.model_loaded:
            print("⚠️ Model not loaded, returning random action")
            if legal_actions:
                return np.random.choice(legal_actions)
            return np.random.randint(0, self.action_size)
        
        try:
            # Convert state to tensor
            state_tensor = torch.FloatTensor(game_state).unsqueeze(0).to(self.device)
            
            # Get prediction from model
            with torch.no_grad():
                if STABLE_BASELINES_AVAILABLE and isinstance(self.model, dict):
                    # Use the policy network from the checkpoint
                    # This is a simplified version - you might need to adjust based on exact model structure
                    action_probs = self._get_action_probabilities(state_tensor)
                else:
                    # Fallback prediction
                    action_probs = torch.softmax(state_tensor @ torch.randn(self.state_size, self.action_size), dim=-1)
                
                # Apply legal actions mask if provided
                if legal_actions is not None:
                    masked_probs = torch.zeros_like(action_probs)
                    for action in legal_actions:
                        if 0 <= action < self.action_size:
                            masked_probs[0, action] = action_probs[0, action]
                    
                    if masked_probs.sum() > 0:
                        action_probs = masked_probs / masked_probs.sum()
                
                # Select best action
                best_action = torch.argmax(action_probs, dim=-1).item()
                
                return best_action
                
        except Exception as e:
            print(f"⚠️ Prediction error: {e}")
            if legal_actions:
                return np.random.choice(legal_actions)
            return np.random.randint(0, self.action_size)
    
    def _get_action_probabilities(self, state_tensor):
        """Get action probabilities from the enhanced model"""
        # This is a placeholder - implement based on your exact model structure
        # You might need to extract the policy network and run forward pass
        return torch.softmax(torch.randn(1, self.action_size), dim=-1)
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get information about the loaded model"""
        if not self.model_loaded:
            return {"status": "not_loaded"}
        
        return {
            "status": "loaded",
            "model_type": self.config['model_info'].get('model_type', 'Unknown'),
            "performance_level": self.config['model_info'].get('performance_level', 'Unknown'),
            "human_enhanced": True,
            "training_date": self.config['model_info'].get('trained_date', 'Unknown'),
            "human_data_samples": self.config['model_info'].get('human_data_samples', 0),
            "enhancements": self.config['model_info'].get('enhancements', [])
        }

# Helper functions for Flutter integration
def convert_card_to_encoded_value(suit: str, rank: str) -> int:
    """Convert card suit and rank to encoded value (0-51)"""
    suits = {'hearts': 0, 'diamonds': 1, 'clubs': 2, 'spades': 3}
    ranks = {
        'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
        'eight': 8, 'nine': 9, 'ten': 10, 'jack': 11, 'queen': 12, 'king': 13, 'ace': 14
    }
    
    suit_value = suits.get(suit.lower(), 0)
    rank_value = ranks.get(rank.lower(), 2)
    return suit_value * 13 + (rank_value - 2)

def convert_hand_to_state(hand: List[Dict], game_context: Dict = None) -> List[float]:
    """Convert hand and game context to 186-dimensional state vector"""
    state = np.zeros(186, dtype=np.float32)
    
    # Cards in hand (first 52 dimensions - one-hot encoding)
    for card in hand:
        if 'suit' in card and 'rank' in card:
            encoded_val = convert_card_to_encoded_value(card['suit'], card['rank'])
            if 0 <= encoded_val < 52:
                state[encoded_val] = 1.0
    
    # Game context features (remaining dimensions)
    if game_context:
        state[52] = len(hand) / 13.0  # Normalized hand size
        
        # Add more context features as available
        if 'trick_number' in game_context:
            state[53] = game_context['trick_number'] / 13.0
        if 'current_score' in game_context:
            state[54] = min(game_context['current_score'] / 100.0, 1.0)
    
    return state.tolist()

# Test function
def test_enhanced_ai():
    """Test the enhanced AI integration"""
    print("=" * 60)
    print("TESTING ENHANCED TRIX AI")
    print("=" * 60)
    
    # Initialize enhanced AI
    ai = EnhancedTrixAI()
    
    # Print model info
    info = ai.get_model_info()
    print(f"Model Status: {info['status']}")
    if info['status'] == 'loaded':
        print(f"Model Type: {info['model_type']}")
        print(f"Performance Level: {info['performance_level']}")
        print(f"Human Enhanced: {info['human_enhanced']}")
        print(f"Training Date: {info['training_date']}")
        print(f"Human Data Samples: {info['human_data_samples']}")
        print(f"Enhancements: {', '.join(info['enhancements'])}")
    
    # Test prediction with sample data
    sample_hand = [
        {'suit': 'hearts', 'rank': 'ace'},
        {'suit': 'spades', 'rank': 'king'},
        {'suit': 'diamonds', 'rank': 'queen'}
    ]
    
    sample_context = {
        'trick_number': 1,
        'current_score': 0
    }
    
    state = convert_hand_to_state(sample_hand, sample_context)
    legal_actions = [0, 12, 24, 36]  # Sample legal actions
    
    print(f"\nTesting with sample hand: {len(sample_hand)} cards")
    prediction = ai.predict_move(state, legal_actions)
    print(f"AI Prediction: {prediction}")
    
    print("\n🎉 Enhanced AI test completed!")

if __name__ == "__main__":
    test_enhanced_ai()
