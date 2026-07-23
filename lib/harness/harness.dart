// Headless-ish harness. Runs the REAL backbone (Deps.i.transcriptionService over
// the native capture + Apple Speech engine) with record/stop/list buttons, so the
// whole loop can be exercised without building the app UI. Run with:
//   flutter run -t lib/harness/harness.dart
// On the simulator this proves capture + persistence + graceful degradation; real
// transcripts appear on a device (and on a sim if on-device Speech is available).
// This is a dev harness, not the app UI. Delete or replace when the UI lands.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Deps.init();
  runApp(const HarnessApp());
}

class HarnessApp extends StatelessWidget {
  const HarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: HarnessScreen());
  }
}

class HarnessScreen extends StatefulWidget {
  const HarnessScreen({super.key});

  @override
  State<HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends State<HarnessScreen> {
  StreamSubscription<dynamic>? _liveSub;
  StreamSubscription<dynamic>? _statusSub;
  List<Entry> _entries = [];
  String _live = '';
  String _status = 'idle';
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    final service = Deps.i.transcriptionService;
    _liveSub = service.liveEvents.listen(
      (event) => _set(() => _live = '${event.text}${event.isFinal ? '  [final]' : ''}'),
      onError: (Object e) => _set(() => _status = 'live error: $e'),
    );
    _statusSub = service.captureStatus.listen((status) => _set(() => _status = 'capture: $status'));
    _refresh();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _refresh() {
    _set(() => _entries = Deps.i.transcriptionService.entries());
  }

  // Awaited by _stop so a stop tapped during the start round-trip cannot error
  // out on "not recording" and strand a hot microphone.
  Future<void>? _startInFlight;

  Future<void> _record() async {
    try {
      _set(() {
        _live = '';
        _status = 'starting';
        _recording = true;
      });
      final starting = Deps.i.transcriptionService.startRecording();
      _startInFlight = starting;
      await starting;
      _set(() => _status = 'recording');
    } catch (e) {
      _set(() {
        _status = 'record failed: $e';
        _recording = false;
      });
    } finally {
      _startInFlight = null;
    }
  }

  Future<void> _stop() async {
    try {
      _set(() => _status = 'stopping');
      final starting = _startInFlight;
      if (starting != null) await starting.catchError((_) {});
      if (!Deps.i.transcriptionService.isRecording) {
        _set(() => _recording = false);
        return;
      }
      final entry = await Deps.i.transcriptionService.stopRecording();
      _set(() {
        _recording = false;
        _status = 'saved ${entry.id} (${entry.isTranscribed ? 'transcribed' : 'untranscribed'})';
      });
      _refresh();
    } catch (e) {
      _set(() {
        _status = 'stop failed: $e';
        _recording = false;
      });
    }
  }

  Future<void> _retranscribe(Entry entry) async {
    try {
      _set(() => _status = 'retranscribing ${entry.id}');
      await Deps.i.transcriptionService.retranscribe(entry);
      _set(() => _status = 'retranscribed ${entry.id}');
      _refresh();
    } catch (e) {
      _set(() => _status = 'retranscribe failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Harness')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _recording ? null : _record,
                      child: const Text('Record'),
                    ),
                    ElevatedButton(onPressed: _recording ? _stop : null, child: const Text('Stop')),
                    ElevatedButton(onPressed: _refresh, child: const Text('Refresh')),
                  ],
                ),
                const SizedBox(height: 8),
                Text('status: $_status'),
                Text('live: $_live'),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final entry = _entries[i];
                return ListTile(
                  dense: true,
                  title: Text(entry.transcript?.fullText ?? '(untranscribed)'),
                  subtitle: Text(
                    '${entry.id}  ${entry.duration.inMilliseconds}ms  ${entry.audioPath.split('/').last}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _retranscribe(entry),
                    child: const Text('Re-transcribe'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
