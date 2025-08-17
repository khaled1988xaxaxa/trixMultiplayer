import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_client.dart';
import '../../screens/game_screen.dart';

class MultiplayerLobbyScreenV2 extends StatefulWidget {
  const MultiplayerLobbyScreenV2({super.key});

  @override
  State<MultiplayerLobbyScreenV2> createState() => _MultiplayerLobbyScreenV2State();
}

class _MultiplayerLobbyScreenV2State extends State<MultiplayerLobbyScreenV2> {
  final TextEditingController _serverUrlController = 
      TextEditingController(text: 'ws://192.168.0.80:8080');
  final TextEditingController _playerNameController = 
      TextEditingController(text: 'Player');
  final TextEditingController _roomNameController = 
      TextEditingController(text: 'My Room');
  
  bool _isConnecting = false;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _playerNameController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('Multiplayer Lobby', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF1E3A8A)],
            ),
          ),
          child: Consumer<MultiplayerClient>(
            builder: (context, client, child) {
              return _buildBody(context, client);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MultiplayerClient client) {
    if (client.lastError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(context, client.lastError!);
      });
    }

    switch (client.state) {
      case MultiplayerState.disconnected:
        return _buildConnectionScreen(client);
      case MultiplayerState.connecting:
        return _buildConnectingScreen();
      case MultiplayerState.connected:
        return _buildLobbyScreen(client);
      case MultiplayerState.inRoom:
        return _buildRoomScreen(client);
      case MultiplayerState.inGame:
        // Navigate to the existing beautiful game screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToGameScreen(context, client);
        });
        return _buildGameLoadingScreen();
      default:
        return _buildConnectionScreen(client);
    }
  }

  Widget _buildConnectionScreen(MultiplayerClient client) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo/Title
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
            ),
            child: const Column(
              children: [
                Icon(Icons.people, size: 60, color: Colors.orange),
                SizedBox(height: 10),
                Text(
                  'Multiplayer Trix',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Connection Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _serverUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    labelStyle: TextStyle(color: Colors.orange),
                    hintText: 'ws://localhost:8080',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                TextField(
                  controller: _playerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Player Name',
                    labelStyle: TextStyle(color: Colors.orange),
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : () => _connect(client),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Connect to Server',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Connecting to server...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyScreen(MultiplayerClient client) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Create Room Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New Room',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _roomNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Room Name',
                          labelStyle: TextStyle(color: Colors.orange),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _createRoom(client),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Available Rooms Section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Rooms',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => client.requestRoomList(),
                        icon: const Icon(Icons.refresh, color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _buildRoomsList(client),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(MultiplayerClient client) {
    if (client.availableRooms.isEmpty) {
      return const Center(
        child: Text(
          'No rooms available\nTap refresh to update',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: client.availableRooms.length,
      itemBuilder: (context, index) {
        final room = client.availableRooms[index];
        return Card(
          color: Colors.white.withOpacity(0.1),
          child: ListTile(
            title: Text(
              room.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${room.players.length}/${room.settings.maxPlayers} players • ${room.status}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: ElevatedButton(
              onPressed: room.status == 'waiting' && room.players.length < room.settings.maxPlayers
                  ? () => client.joinRoom(room.id)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Join', style: TextStyle(color: Colors.white)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomScreen(MultiplayerClient client) {
    final room = client.currentRoom;
    if (room == null) return _buildLobbyScreen(client);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Room Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => client.leaveRoom(),
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    ),
                  ],
                ),
                Text(
                  'Room ID: ${room.id}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Players List
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Players',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Add Bot Button (only for host if room has space)
                  if (client.isHost && client.canAddBot)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddBotDialog(context, client),
                          icon: const Icon(Icons.smart_toy, color: Colors.white),
                          label: Text(
                            'Add AI Bot (${client.availableBotSlots} slots available)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: room.players.length,
                      itemBuilder: (context, index) {
                        final player = room.players[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          child: ListTile(
                            leading: Icon(
                              player.isAI ? Icons.smart_toy : Icons.person,
                              color: player.isConnected ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              player.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${player.position}${player.isHost ? ' (Host)' : ''}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: player.isAI
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Chip(
                                        label: Text('AI', style: TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.blue,
                                      ),
                                      if (client.isHost) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => client.removeBot(player.sessionId),
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          tooltip: 'Remove Bot',
                                        ),
                                      ],
                                    ],
                                  )
                                : client.isHost && !player.isHost
                                    ? IconButton(
                                        onPressed: () => client.kickPlayer(player.sessionId),
                                        icon: const Icon(Icons.person_remove, color: Colors.orange),
                                        tooltip: 'Kick Player',
                                      )
                                    : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Start Game Button (only for host)
          if (client.isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: room.players.length >= 4 ? () => client.startGame() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  room.players.length >= 4 ? 'Start Game' : 'Waiting for players...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Starting multiplayer game...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(MultiplayerClient client) async {
    setState(() => _isConnecting = true);
    
    final serverUrl = _serverUrlController.text.trim();
    final playerName = _playerNameController.text.trim();
    
    if (serverUrl.isEmpty || playerName.isEmpty) {
      _showErrorDialog(context, 'Please enter server URL and player name');
      setState(() => _isConnecting = false);
      return;
    }
    
    final success = await client.connect(serverUrl, playerName);
    
    setState(() => _isConnecting = false);
    
    if (success) {
      client.requestRoomList();
    }
  }

  void _createRoom(MultiplayerClient client) {
    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      _showErrorDialog(context, 'Please enter a room name');
      return;
    }
    
    client.createRoom(roomName);
  }

  void _navigateToGameScreen(BuildContext context, MultiplayerClient client) {
    // Navigate to your existing beautiful game screen but in multiplayer mode
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const GameScreen(),
        settings: RouteSettings(
          arguments: {
            'isMultiplayer': true,
            'multiplayerClient': client,
          },
        ),
      ),
    );
  }

  void _showAddBotDialog(BuildContext context, MultiplayerClient client) {
    final botNameController = TextEditingController();
    String selectedDifficulty = 'medium';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A8A),
          title: const Text('Add AI Bot', style: TextStyle(color: Colors.orange)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: botNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Bot Name (optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Difficulty: ', style: TextStyle(color: Colors.white)),
                  DropdownButton<String>(
                    value: selectedDifficulty,
                    dropdownColor: const Color(0xFF1E3A8A),
                    items: ['easy', 'medium', 'hard', 'expert'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedDifficulty = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final botName = botNameController.text.trim().isEmpty 
                    ? null 
                    : botNameController.text.trim();
                client.addBot(botName: botName, difficulty: selectedDifficulty);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Add Bot', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
