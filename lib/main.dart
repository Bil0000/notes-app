import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deviceID = const Uuid().v4();

  await Supabase.initialize(
    url: 'https://nznhwuyoynclfhwcjtic.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmh3dXlveW5jbGZod2NqdGljIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTQ3OTYwNDEsImV4cCI6MjAxMDM3MjA0MX0.V9iwmM_3KZ4stzAPGPK7ocjqvoMSNU4285xey28Igc8',
  );

  runApp(MyApp(deviceID: deviceID));
}

class MyApp extends StatelessWidget {
  final String deviceID;

  const MyApp({Key? key, required this.deviceID}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notes app',
      home: MyHomePage(deviceID: deviceID),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String deviceID;

  const MyHomePage({Key? key, required this.deviceID}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _notesStream =
      Supabase.instance.client.from('notes').stream(primaryKey: ['id']);
  List<Map<String, dynamic>> notes = [];

  @override
  void initState() {
    super.initState();

    // Load filtered notes from local storage when the app starts
    _loadFilteredNotes();

    // Start listening to the Supabase stream to keep the notes updated
    _notesStream.listen((data) {
      setState(() {
        // Combine the filtered notes from local storage with new data from the stream
        final newNotes =
            data.where((note) => note['device_id'] == widget.deviceID).toList();

        for (final newNote in newNotes) {
          // Check if the note with the same 'id' exists in the list
          final existingNoteIndex =
              notes.indexWhere((note) => note['id'] == newNote['id']);

          if (existingNoteIndex != -1) {
            // Update the existing note if it exists
            notes[existingNoteIndex] = newNote;
          } else {
            // Add the new note if it doesn't exist
            notes.add(newNote);
          }
        }

        _saveFilteredNotes(notes); // Save the combined notes to local storage
      });
    });
  }

  // Load filtered notes from local storage
  Future<void> _loadFilteredNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final filteredNotesJson = prefs.getString('filtered_notes');
    if (filteredNotesJson != null) {
      final filteredNotes = json.decode(filteredNotesJson) as List;
      setState(() {
        notes = filteredNotes.cast<Map<String, dynamic>>();
      });
    }
  }

  // Save filtered notes to local storage
  Future<void> _saveFilteredNotes(
      List<Map<String, dynamic>> filteredNotes) async {
    final prefs = await SharedPreferences.getInstance();
    final filteredNotesJson = json.encode(filteredNotes);
    await prefs.setString('filtered_notes', filteredNotesJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              String editedNoteText = notes[index]['body'];

              return Slidable(
                key: UniqueKey(),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (direction) async {
                        String editedNoteText = notes[index]['body'];
                        final updatedNote = await showDialog(
                          context: context,
                          builder: ((context) {
                            return AlertDialog(
                              title: const Text('Edit Note'),
                              content: TextFormField(
                                initialValue: editedNoteText,
                                onChanged: (value) {
                                  editedNoteText = value;
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop(editedNoteText);
                                    await Supabase.instance.client
                                        .from('notes')
                                        .update({'body': editedNoteText})
                                        .eq('id', notes[index]['id'])
                                        .execute();
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          }),
                        );

                        setState(() {
                          notes[index]['body'] = updatedNote ?? editedNoteText;
                        });
                      },
                      backgroundColor: Colors.green,
                      icon: Icons.edit,
                      label: 'Edit Note',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (direction) async {
                        final noteId = notes[index]['id'];
                        await Supabase.instance.client
                            .from('notes')
                            .delete()
                            .eq('id', noteId)
                            .execute();

                        setState(() {
                          notes.removeAt(index);
                        });
                      },
                      backgroundColor: Colors.red,
                      icon: Icons.delete,
                      label: 'Delete Note',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(editedNoteText),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: ((context) {
              String newNoteText = '';
              return AlertDialog(
                title: const Text('Add a Note'),
                content: TextFormField(
                  onChanged: (value) {
                    newNoteText = value;
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (newNoteText.isNotEmpty) {
                        await Supabase.instance.client.from('notes').insert({
                          'body': newNoteText,
                          'device_id': widget.deviceID
                        }).execute();
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            }),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
