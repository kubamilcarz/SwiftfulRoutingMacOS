import XCTest
import SwiftUI
@testable import SwiftfulRouting

final class SwiftfulRoutingTests: XCTestCase {
    
    @MainActor
    private func makeDestination(
        id: String,
        segue: SegueOption = .push,
        location: SegueLocation = .insert,
        animates: Bool = false
    ) -> AnyDestination {
        AnyDestination(id: id, segue: segue, location: location, animates: animates) { _ in
            Text(id)
        }
    }
    
    @MainActor
    private func flushMainActor(iterations: Int = 20) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }
    
    @MainActor
    private func makeViewModel() -> RouterViewModel {
        let viewModel = RouterViewModel()
        viewModel.insertRootView(
            rootRouterId: nil,
            view: makeDestination(id: RouterViewModel.rootId, segue: .fullScreenCover, animates: false)
        )
        return viewModel
    }
    
    @MainActor
    func testShowPushFromRootAddsScreenToRootPushStack() async {
        let viewModel = makeViewModel()
        
        viewModel.showScreens(
            routerId: RouterViewModel.rootId,
            destinations: [makeDestination(id: "screen_A")]
        )
        await flushMainActor()
        
        XCTAssertEqual(viewModel.activeScreenStacks.count, 2)
        XCTAssertEqual(viewModel.activeScreenStacks[1].screens.map(\.id), ["screen_A"])
    }
    
    @MainActor
    func testConsecutivePushScreensAppendInOrder() async {
        let viewModel = makeViewModel()
        
        viewModel.showScreens(
            routerId: RouterViewModel.rootId,
            destinations: [
                makeDestination(id: "screen_A"),
                makeDestination(id: "screen_B"),
                makeDestination(id: "screen_C")
            ]
        )
        await flushMainActor()
        
        XCTAssertEqual(viewModel.activeScreenStacks.count, 2)
        XCTAssertEqual(viewModel.activeScreenStacks[1].screens.map(\.id), ["screen_A", "screen_B", "screen_C"])
    }
    
    @MainActor
    func testDismissScreensToRouteKeepsRemainingPushPath() async {
        let viewModel = makeViewModel()
        
        viewModel.showScreens(
            routerId: RouterViewModel.rootId,
            destinations: [
                makeDestination(id: "screen_A"),
                makeDestination(id: "screen_B"),
                makeDestination(id: "screen_C")
            ]
        )
        await flushMainActor()
        
        viewModel.dismissScreens(to: "screen_B", animates: true)
        
        XCTAssertEqual(viewModel.activeScreenStacks.count, 2)
        XCTAssertEqual(viewModel.activeScreenStacks[1].screens.map(\.id), ["screen_A", "screen_B"])
    }
    
    @MainActor
    func testSheetEnvironmentMaintainsIndependentNestedPushStack() async {
        let viewModel = makeViewModel()
        
        viewModel.showScreens(
            routerId: RouterViewModel.rootId,
            destinations: [makeDestination(id: "sheet_1", segue: .sheet)]
        )
        await flushMainActor()
        
        XCTAssertEqual(viewModel.activeScreenStacks.map(\.segue), [.fullScreenCover, .push, .sheet, .push])
        XCTAssertTrue(viewModel.activeScreenStacks[1].screens.isEmpty)
        XCTAssertTrue(viewModel.activeScreenStacks[3].screens.isEmpty)
        
        viewModel.showScreens(
            routerId: "sheet_1",
            destinations: [makeDestination(id: "sheet_1_push_A")]
        )
        await flushMainActor()
        
        XCTAssertTrue(viewModel.activeScreenStacks[1].screens.isEmpty)
        XCTAssertEqual(viewModel.activeScreenStacks[3].screens.map(\.id), ["sheet_1_push_A"])
    }
    
    @MainActor
    func testSeparateRouterViewModelsDoNotShareRootPushState() async {
        let firstViewModel = makeViewModel()
        let secondViewModel = makeViewModel()
        
        firstViewModel.showScreens(
            routerId: RouterViewModel.rootId,
            destinations: [makeDestination(id: "first_only_push")]
        )
        await flushMainActor()
        
        XCTAssertEqual(firstViewModel.activeScreenStacks[1].screens.map(\.id), ["first_only_push"])
        XCTAssertTrue(secondViewModel.activeScreenStacks[1].screens.isEmpty)
    }
    
    @MainActor
    func testInsertRootViewIsIdempotent() {
        let viewModel = RouterViewModel()
        
        viewModel.insertRootView(
            rootRouterId: "first_root_id",
            view: makeDestination(id: RouterViewModel.rootId, segue: .fullScreenCover, animates: false)
        )
        
        viewModel.insertRootView(
            rootRouterId: "second_root_id",
            view: makeDestination(id: RouterViewModel.rootId, segue: .fullScreenCover, animates: false)
        )
        
        XCTAssertEqual(viewModel.activeScreenStacks.count, 2)
        XCTAssertEqual(viewModel.activeScreenStacks[0].segue, .fullScreenCover)
        XCTAssertEqual(viewModel.activeScreenStacks[1].segue, .push)
        XCTAssertEqual(viewModel.activeScreenStacks[0].screens.count, 1)
        XCTAssertEqual(viewModel.rootRouterIdFromDeveloper, "first_root_id")
    }
    
    @MainActor
    func testIsStrictPrefixPathAcceptsValidPop() {
        let activePath = [
            makeDestination(id: "screen_A"),
            makeDestination(id: "screen_B"),
            makeDestination(id: "screen_C")
        ]
        let poppedPath = [
            makeDestination(id: "screen_A"),
            makeDestination(id: "screen_B")
        ]
        
        XCTAssertTrue(isStrictPrefixPath(poppedPath, of: activePath))
    }
    
    @MainActor
    func testIsStrictPrefixPathRejectsTransientNonPrefixUpdate() {
        let activePath = [
            makeDestination(id: "screen_A"),
            makeDestination(id: "screen_B")
        ]
        let transientPath = [
            makeDestination(id: "screen_X")
        ]
        
        XCTAssertFalse(isStrictPrefixPath(transientPath, of: activePath))
        XCTAssertFalse(isStrictPrefixPath(activePath, of: activePath))
    }
}
