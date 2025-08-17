import 'package:flutter/material.dart';

class BiddingWidget extends StatefulWidget {
  final Function(int) onBid;
  final int currentBid;

  const BiddingWidget({
    super.key,
    required this.onBid,
    required this.currentBid,
  });

  @override
  State<BiddingWidget> createState() => _BiddingWidgetState();
}

class _BiddingWidgetState extends State<BiddingWidget> {
  int selectedBid = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'المزايدة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Current bid display
          if (widget.currentBid > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'أعلى مزايدة: ${widget.currentBid}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Bid buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Bid amounts
              for (int bid in [7, 8, 9, 10, 11, 12, 13])
                _buildBidButton(bid, bid > widget.currentBid),
              
              // Pass button
              _buildPassButton(),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Confirm button (if bid selected)
          if (selectedBid > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onBid(selectedBid);
                  setState(() {
                    selectedBid = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  selectedBid == -1 ? 'باس' : 'مزايدة $selectedBid',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBidButton(int bid, bool isEnabled) {
    final isSelected = selectedBid == bid;
    
    return GestureDetector(
      onTap: isEnabled ? () {
        setState(() {
          selectedBid = bid;
        });
      } : null,
      child: Container(
        width: 60,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.orange 
              : isEnabled 
                  ? Colors.grey[800]
                  : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Colors.orange 
                : isEnabled 
                    ? Colors.grey[600]! 
                    : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            bid.toString(),
            style: TextStyle(
              color: isEnabled ? Colors.white : Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassButton() {
    final isSelected = selectedBid == -1;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedBid = -1;
        });
      },
      child: Container(
        width: 80,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            'باس',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}