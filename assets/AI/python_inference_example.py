#!/usr/bin/env python3
"""
Simple Python inference example for the deployed Trix AI agent.
Use this to test the agent before Flutter integration.
"""

import torch
import numpy as np
import json
import sys
import os

# Add the project root to the path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.ppo_agent import PPOAgent
from trex_env import TrexEnv

class TrixAIInference:
    """Simple inference wrapper for the Trix AI agent"""
    
    def __init__(self, model_path: str = None):
        # Load configuration
        with open("agent_config.json", 'r') as f:
            self.config = json.load(f)
        
        self.state_size = self.config['model_info']['state_size']
        self.action_size = self.config['model_info']['action_size']
        
        # Load the model
        if model_path is None:
            model_path = "trix_agent_full.pt"
        
        self.agent = PPOAgent(
            state_size=self.state_size,
            action_size=self.action_size,
            lr=0.0003,
            device='cpu'
        )
        
        # Load the model weights
        checkpoint = torch.load(model_path, map_location='cpu')
        self.agent.policy.load_state_dict(checkpoint['policy_state_dict'])
        self.agent.policy.eval()  # Set to evaluation mode
        
        print(f"✓ Trix AI Agent loaded")
        print(f"  State size: {self.state_size}")
        print(f"  Action size: {self.action_size}")
        print(f"  Win rate: {self.config['model_info']['win_rate']:.1%}")
    
    def predict(self, game_state: np.ndarray, legal_actions: list) -> dict:
        """
        Get AI prediction for the given game state
        
        Args:
            game_state: numpy array of shape (state_size,)
            legal_actions: list of legal action indices
            
        Returns:
            dict with prediction results
        """
        if len(game_state) != self.state_size:
            raise ValueError(f"Game state must have {self.state_size} dimensions")
        
        # Get action from agent
        action, log_prob, value = self.agent.select_action(
            game_state, legal_actions, deterministic=True
        )
        
        # Get full action probabilities for analysis
        with torch.no_grad():
            state_tensor = torch.FloatTensor(game_state).unsqueeze(0)
            action_mask = torch.zeros(1, self.action_size)
            for legal_action in legal_actions:
                action_mask[0, legal_action] = 1.0
            
            action_probs, pred_value = self.agent.policy(state_tensor, action_mask)
            action_probs = torch.softmax(action_probs, dim=-1)
            
            # Get top 3 actions
            top_actions = []
            for legal_action in legal_actions:
                prob = action_probs[0, legal_action].item()
                top_actions.append({'action': legal_action, 'probability': prob})
            
            top_actions.sort(key=lambda x: x['probability'], reverse=True)
        
        return {
            'best_action': action,
            'confidence': log_prob,
            'value_estimate': value,
            'top_actions': top_actions[:3],
            'legal_actions': legal_actions
        }
    
    def get_model_info(self) -> dict:
        """Get model information"""
        return self.config['model_info']

def demo_game():
    """Demonstrate the AI agent in a game scenario"""
    print("=" * 60)
    print("TRIX AI AGENT DEMO")
    print("=" * 60)
    
    # Change to deployment directory
    os.chdir("./deployment")
    
    # Initialize AI agent
    ai = TrixAIInference()
    
    # Initialize game environment
    env = TrexEnv(seed=42)
    observations = env.reset()
    
    print(f"\n🎮 Game started!")
    print(f"Model info: {ai.get_model_info()}")
    
    # Simulate a few AI moves
    for turn in range(3):
        print(f"\n--- Turn {turn + 1} ---")
        
        # Check if player 0 has a turn
        if 0 in observations and observations[0] is not None:
            legal_actions = env.get_legal_actions(0)
            
            if legal_actions:
                # Get AI prediction
                prediction = ai.predict(observations[0], legal_actions)
                
                print(f"Legal actions: {legal_actions}")
                print(f"AI recommends action: {prediction['best_action']}")
                print(f"Confidence (log prob): {prediction['confidence']:.3f}")
                print(f"Value estimate: {prediction['value_estimate']:.3f}")
                
                print("Top 3 action probabilities:")
                for i, action_info in enumerate(prediction['top_actions']):
                    print(f"  {i+1}. Action {action_info['action']}: {action_info['probability']:.3f}")
                
                # Execute the action
                actions = {0: prediction['best_action']}
                observations, rewards, dones, truncated, infos = env.step(actions)
                
                if 0 in rewards:
                    print(f"Reward received: {rewards[0]:.3f}")
            else:
                print("No legal actions available")
                break
        else:
            print("No observation for player 0")
            break
    
    print("\n🎉 Demo completed!")
    print("\nTo use in your Flutter app:")
    print("1. Copy trix_agent_model.pt to your Flutter assets")
    print("2. Use the TrixAIAgent Dart class")
    print("3. Convert your game state to the expected format")
    print("4. Call predictMove() to get AI recommendations")

if __name__ == "__main__":
    demo_game()
