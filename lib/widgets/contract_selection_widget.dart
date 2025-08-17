import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/player.dart';

class ContractSelectionWidget extends StatefulWidget {
  final Function(TrexContract) onContractSelected;
  final List<TrexContract> availableContracts;
  final PlayerPosition currentKing;

  const ContractSelectionWidget({
    super.key,
    required this.onContractSelected,
    required this.availableContracts,
    required this.currentKing,
  });

  @override
  State<ContractSelectionWidget> createState() => _ContractSelectionWidgetState();
}

class _ContractSelectionWidgetState extends State<ContractSelectionWidget> {
  TrexContract? selectedContract;

  @override
  Widget build(BuildContext context) { // Build the contract selection widget
    // Ensure the widget does not exceed 70% of the screen height
    return ConstrainedBox(
      constraints: BoxConstraints( // Set maximum height to 70% of screen height
        maxHeight: MediaQuery.of(context).size.height * 0.7, // Max 70% of screen height
      ),
      child: Container(
        padding: const EdgeInsets.all(16), // Add padding around the container
        margin: const EdgeInsets.symmetric(horizontal: 20), // Add horizontal margin
        decoration: BoxDecoration( // Add a rounded border
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use minimum size to fit content
          children: [
            // Title
            const Text(
              'Select Contract',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            
            // King indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'King: ${widget.currentKing.arabicName}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Confirm button
            if (selectedContract != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onContractSelected(selectedContract!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 1, 179, 243),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Select ${selectedContract!.arabicName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Contract cards in scrollable area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: widget.availableContracts.map((contract) => 
                    _buildContractCard(contract)).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 
            
          ],
        ),
      ),
    );
  }

  Widget _buildContractCard(TrexContract contract) {
    final isSelected = selectedContract == contract;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedContract = contract;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6), 
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.orange.withOpacity(0.2) 
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? Colors.orange 
                : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              children: [
                // Contract icon
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getContractColor(contract),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getContractIcon(contract),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                
                // Contract name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: [
                      Text(
                        contract.arabicName,
                        style: TextStyle(
                          color: isSelected ? Colors.orange : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contract.englishName,
                        style: TextStyle(
                          color: isSelected ? Colors.orange[300] : Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Score indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: contract.baseScore > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contract.baseScore > 0 
                        ? '+${contract.baseScore}' 
                        : '${contract.baseScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Contract description
            Text(
              contract.description,
              style: TextStyle(
                color: isSelected ? Colors.orange[200] : Colors.grey[300],
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getContractColor(TrexContract contract) {
    switch (contract) {
      case TrexContract.kingOfHearts:
        return Colors.red[700]!;
      case TrexContract.queens:
        return Colors.purple[700]!;
      case TrexContract.diamonds:
        return Colors.blue[700]!;
      case TrexContract.collections:
        return Colors.green[700]!;
      case TrexContract.trex:
        return Colors.orange[700]!;
    }
  }

  IconData _getContractIcon(TrexContract contract) {
    switch (contract) {
      case TrexContract.kingOfHearts:
        return Icons.favorite;
      case TrexContract.queens:
        return Icons.face;
      case TrexContract.diamonds:
        return Icons.diamond;
      case TrexContract.collections:
        return Icons.collections;
      case TrexContract.trex:
        return Icons.star;
    }
  }
}