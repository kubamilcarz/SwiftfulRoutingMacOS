# Duo regression harness

A local simulator app for checking real hinge, display, rotation, and multitasking changes.
It uses the package directly, without overriding size classes, window sizes, or hinge data.
The app continuously verifies route history, split selection, and dismissal callbacks while a
prepared scenario is armed. Failures remain visible even if a later layout restores the route.

This complements the automated `SplitCompactHostingTests`, which exercise native SwiftUI hosting
with explicitly overridden size classes and window bounds. Those tests are synthetic layout
coverage; running them on a Duo simulator alone does not test physical pose transitions.

Requires Xcode 27.1+, an installed iOS 27.1 Duo simulator, and an Apple Silicon or Intel Mac matching
the simulator architecture. From this directory:

```sh
xcrun simctl list devices available
bash build-and-run.sh SIMULATOR-UUID
# Native scene rotations with continuous assertions:
bash build-and-run.sh SIMULATOR-UUID --rotate
# Repeat with a resizable sheet and nested sheet history:
bash build-and-run.sh SIMULATOR-UUID --rotate --sheet
```

The script boots the chosen simulator if needed. Build outputs and the app bundle stay in the system temporary
directory. The script builds the package, compiles these SwiftUI fixture files, signs the local
bundle, then installs and launches it with the initial A → B branch prepared. It does not add a target to the shipping package.

`--rotate` requests landscape-left, landscape-right, and portrait through
`UIWindowScene.requestGeometryUpdate`, waits for native transitions, and records checkpoints.
These are actual scene rotations, distinct from the bounds/trait overrides in the hosting tests.
They do not exercise the hinge or enter Split View multitasking; those operations use Device Hub.

## Real-device-pose scenarios

Use Device Hub's controls for the following operations. Tap **Record checkpoint** after each
completed transition. Record the observed horizontal and vertical size classes rather than
assuming them from an orientation or pose. All checkpoints must show PASS and no failures.

| Preparation | Device Hub operation | Required result |
| --- | --- | --- |
| Prepare A → B | Open flat; rotate through both landscape directions and portrait | Selection A; history `[A, B]`; zero dismissals |
| Same branch | Partially fold like a book, then unfold without rotating | Same history and selection; capture a checkpoint pair with unchanged horizontal size class |
| Same branch | Rotate and partially fold like a laptop, then unfold | Same history and selection; controls stay usable |
| Same branch | Close to the outer display, rotate it, then reopen | Same history and selection across both displays |
| Same branch on inner display | Drag the home indicator into Split View multitasking on the left, then right; return full screen | Same history and selection; capture an unchanged-size-class resize pair where available |
| Prepare A → B + sheet + nested push | Repeat all applicable pose, rotation, and multitasking operations | Both `[A, B]` and sheet `[sheet_detail]` histories survive; zero dismissals |
| Sheet scenario | Dismiss sheet and verify callbacks | Exactly `sheet_detail`, then `sheet`; root history `[A, B]` survives |
| Root branch | Prepare native Back check; immediately tap native Back after a layout transition; Check native Back | Selection A; history `[A]`; B dismissed exactly once |

Also repeat folding and resizing after returning to A (no deeper pushes). Choose **Prepare sidebar Back check**, tap native Back, then **Check sidebar Back**. Returning to the sidebar
with the native Back control must dismiss A once and clear the selection; layout changes alone
must not do so.

For custom swipe-back, choose **Show custom swipe screen** from B. In each bar arrangement:

- Tap the edge button and toolbar control: the counter increases without dismissing the transition.
- Scroll vertically from the content edge: the list scrolls without dismissing the transition.
- Drag inward more than 30 points from the appropriate content edge: return to B once.
- A drag started over system controls, the active fold, or a camera occlusion must not dismiss it.

## Saved evidence

The latest report is written to the app's Documents directory as `duo-regression.json`. It contains
recorded geometry, hinge state, checkpoints, histories, callbacks, and retained failures. Obtain its
container path with:

```sh
xcrun simctl get_app_container SIMULATOR-UUID com.swiftfulrouting.DuoRegression data
```

An initial launch or an empty checkpoint list is not evidence that the pose matrix passed. The
real Device Hub matrix requires interacting with the simulator and reviewing the recorded results.
