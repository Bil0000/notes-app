// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, unused_local_variable

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Generate a unique device ID (UUID)
  final deviceID = Uuid().v4();

  await Supabase.initialize(
    url: 'https://nznhwuyoynclfhwcjtic.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmh3dXlveW5jbGZod2NqdGljIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTQ3OTYwNDEsImV4cCI6MjAxMDM3MjA0MX0.V9iwmM_3KZ4stzAPGPK7ocjqvoMSNU4285xey28Igc8', // Replace with your Supabase anonymous key
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
    _notesStream.listen((data) {
      setState(() {
        // Filter notes based on deviceID
        notes =
            data.where((note) => note['device_id'] == widget.deviceID).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
      ),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          String editedNoteText = notes[index]['body'];

          return Dismissible(
            key: UniqueKey(),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            secondaryBackground: Container(
              color: Colors.green,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
              ),
            ),
            onDismissed: (direction) async {
              if (direction == DismissDirection.endToStart) {
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
              } else if (direction == DismissDirection.startToEnd) {
                final noteId = notes[index]['id'];
                await Supabase.instance.client
                    .from('notes')
                    .delete()
                    .eq('id', noteId)
                    .execute();
              }
            },
            child: ListTile(
              title: Text(editedNoteText),
            ),
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
                        // Include the device ID when inserting a new note
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
