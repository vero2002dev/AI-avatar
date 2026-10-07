# Milestone 1 Hardware Validation

Run a signed local build on the target Mac. CI does not execute this checklist. Record commit SHA, macOS version, chip/RAM, camera names/models, iOS version, connection method and each result. Leave untested items unchecked.

## Permission and Lifecycle

- [ ] First launch requests Camera access, without requesting Microphone access.
- [ ] Grant: the selected device opens and real moving video appears.
- [ ] Deny: the app shows access disabled and Camera Settings opens the correct privacy pane.
- [ ] Re-enable permission and return to the app: discovery/capture resumes, or relaunch if required by macOS.
- [ ] Stop: camera light turns off and frame delivery stops.
- [ ] Start: video resumes and statistics start a fresh measurement.
- [ ] Close the window: capture stops. Reopen: capture starts normally.

## Discovery and Selection

- [ ] Mac camera name matches macOS/AVFoundation and its preview is actual video.
- [ ] iPhone Continuity Camera is discovered and preferred in automatic mode.
- [ ] Check both USB and wireless iPhone capture, using Apple's required setup.
- [ ] External USB camera appears with its actual device name.
- [ ] Desk View is classified separately and is not preferred over a normal camera.
- [ ] Manually select each camera while live: selected name and image change together.
- [ ] Connect an iPhone while another camera is manually selected: manual selection remains.
- [ ] Enable Automatic: selection moves to the preferred connected camera.
- [ ] Two devices with identical names remain individually selectable.

## Disconnect and Failure

- [ ] Disconnect the active device: capture falls back to a remaining device.
- [ ] Disconnect every device: empty state appears, without stale video or a crash.
- [ ] Reconnect a manually pinned device: the app returns to that camera.
- [ ] Disconnect/reconnect while stopped: the app updates selection but remains stopped.
- [ ] An unavailable/busy camera reports the actual failure; a failed switch preserves the previous camera where possible.
- [ ] Interrupt camera availability, including iPhone use/unlock/call: status and recovery reflect actual frames.
- [ ] Interrupt frame delivery for over three seconds: the app stops claiming Live and reports waiting.
- [ ] A denied/restricted camera never leaves a stale live preview visible.

## Performance and Presentation

- [ ] Resize the window: video preserves aspect ratio and camera names/controls do not overlap.
- [ ] Actual frame dimensions/FPS agree with capture; no fixed target value is shown as measurement.
- [ ] Run for at least ten minutes on M2 / 8 GB and record FPS, drops, resident memory and visible latency.
- [ ] Switch cameras repeatedly during the endurance run; verify no growing queue/memory and no UI freezes.

## Result Record

```text
Commit:
macOS / chip / RAM:
Camera names and models:
iOS / USB or wireless:
Permission result:
Switching / disconnect / reconnect result:
Preview / resize result:
Duration / delivered FPS / drops:
Resident memory / measured latency:
Failures and reproduction steps:
Tester / date:
```

Only mark Milestone 1 complete after the relevant permission, physical camera and lifecycle checks pass and the compile/test workflow is green.
