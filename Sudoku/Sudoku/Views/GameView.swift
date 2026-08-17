import SudokuKit
import SwiftData
import SwiftUI
import UIKit

enum GameMode: Hashable {
    case new(Difficulty)
    case resume
}

struct GameView: View {
    let mode: GameMode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: GameViewModel?

    var body: some View {
        Group {
            if let viewModel {
                GameContentView(vm: viewModel, exit: { dismiss() })
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Generating puzzle…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await setUp() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                viewModel?.pause()
            case .active:
                viewModel?.resume()
            default:
                break
            }
        }
        .onDisappear { viewModel?.pause() }
    }

    private func setUp() async {
        guard viewModel == nil else { return }
        switch mode {
        case .resume:
            let records = (try? modelContext.fetch(FetchDescriptor<SavedGame>())) ?? []
            if let record = records.first, let vm = GameViewModel(saved: record, context: modelContext) {
                viewModel = vm
            } else {
                dismiss()
            }
        case .new(let difficulty):
            if UITestSupport.useFixedPuzzle {
                viewModel = GameViewModel(puzzle: UITestSupport.fixedPuzzle, context: modelContext)
                return
            }
            // Generation is CPU-bound — run it off the main actor.
            let puzzle = await Task.detached(priority: .userInitiated) {
                Generator.generate(difficulty: difficulty)
            }.value
            viewModel = GameViewModel(puzzle: puzzle, context: modelContext)
        }
    }
}

private struct GameContentView: View {
    @Bindable var vm: GameViewModel
    let exit: () -> Void
    @State private var showGuide = false
    @AppStorage(SettingsKeys.mistakeMode) private var mistakeModeRaw = MistakeMode.instantSolution.rawValue
    @AppStorage(SettingsKeys.errorLimitEnabled) private var errorLimitEnabled = false
    @AppStorage(SettingsKeys.showTimer) private var showTimer = true
    @AppStorage(SettingsKeys.showScore) private var showScore = true

    private var mistakeMode: MistakeMode {
        MistakeMode(rawValue: mistakeModeRaw) ?? .instantSolution
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            hintBanner
            layerBar
            BoardView(vm: vm)
                .padding(.horizontal, 8)
            GameToolbar(vm: vm, showCheck: mistakeMode == .onDemand)
            NumberPadView(vm: vm)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .navigationTitle(vm.difficulty.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGuide = true
                } label: {
                    Label("Techniques", systemImage: "book")
                }
                .accessibilityIdentifier("guide")
            }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                TechniqueGuideView(isSheet: true)
            }
        }
        .overlay {
            if vm.isPaused {
                PauseOverlay(vm: vm)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = AppSettings.keepScreenOn
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $vm.showVictory) {
            VictoryView(vm: vm, onDone: exit)
                .interactiveDismissDisabled()
        }
        .alert("Out of mistakes", isPresented: $vm.showFailure) {
            Button("Back to Home") { exit() }
        } message: {
            Text("You reached \(GameViewModel.errorLimit) mistakes. This puzzle is recorded as a loss.")
        }
    }

    private var header: some View {
        HStack {
            Label {
                Text(errorLimitEnabled
                     ? "\(vm.mistakeCount)/\(GameViewModel.errorLimit)"
                     : "\(vm.mistakeCount)")
            } icon: {
                Image(systemName: "xmark.circle")
            }
            .foregroundStyle(vm.mistakeCount > 0 ? Theme.mistakeText : Color.secondary)
            .accessibilityLabel("\(vm.mistakeCount) mistakes")

            Spacer()

            if vm.canAutoComplete {
                Button {
                    vm.autoComplete()
                } label: {
                    Label("Auto-complete", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("autocomplete")
            } else if showScore {
                Text("Score \(vm.score)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .overlay(alignment: .trailing) { scoreFlashView }
                    .animation(.easeOut(duration: 0.25), value: vm.scoreFlash)
            } else {
                Text("Progress \(vm.progressText)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if showTimer {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Label(vm.elapsed.timerString, systemImage: "clock")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Elapsed time \(vm.elapsed.timerString)")
                    }
                }
                Button {
                    vm.pauseGame()
                } label: {
                    Image(systemName: "pause.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("pause")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
    }

    /// Floating "+N" that rises and fades on each score award.
    @ViewBuilder
    private var scoreFlashView: some View {
        if let flash = vm.scoreFlash {
            Text("+\(flash.amount)")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .id(flash.id)
                .offset(x: 30, y: -4)
                .transition(.asymmetric(
                    insertion: .offset(y: 10).combined(with: .opacity),
                    removal: .offset(y: -8).combined(with: .opacity)
                ))
                .task(id: flash.id) {
                    try? await Task.sleep(for: .seconds(0.8))
                    if vm.scoreFlash?.id == flash.id {
                        withAnimation(.easeOut(duration: 0.3)) { vm.scoreFlash = nil }
                    }
                }
        }
    }

    /// Chain-layer strip: switch between the real game and what-if sheets,
    /// peel the top sheet, or discard them all.
    @ViewBuilder
    private var layerBar: some View {
        if !vm.layers.isEmpty {
            HStack(spacing: 8) {
                layerChip("Game", isActive: vm.viewedLayer == nil, id: "layer_game") {
                    vm.viewLayer(nil)
                }
                ForEach(vm.layers.indices, id: \.self) { i in
                    layerChip("L\(i + 1)", isActive: vm.viewedLayer == i, id: "layer_\(i + 1)") {
                        vm.viewLayer(i)
                    }
                }
                if !vm.canEditViewedState {
                    Image(systemName: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Read-only — edits go to the top layer")
                }
                Spacer()
                Button {
                    vm.dropTopLayer()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove top layer")
                .accessibilityIdentifier("layer_drop")
                Button {
                    vm.clearLayers()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Discard all layers")
                .accessibilityIdentifier("layer_clear")
            }
            .padding(.horizontal, 16)
        }
    }

    private func layerChip(
        _ title: String, isActive: Bool, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(isActive ? Color.accentColor : Color(.secondarySystemBackground)))
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var hintBanner: some View {
        if let message = vm.hintMessage {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.footnote)
                Spacer()
                Button {
                    vm.hintMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .accessibilityLabel("Dismiss hint")
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .task(id: message) {
                try? await Task.sleep(for: .seconds(6))
                if vm.hintMessage == message { vm.hintMessage = nil }
            }
        }
    }
}

private struct PauseOverlay: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Paused")
                .font(.title.bold())

            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.elapsed.timerString)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                VStack(spacing: 4) {
                    Text("Difficulty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.difficulty.displayName)
                        .font(.title3.weight(.semibold))
                }
            }

            VStack(spacing: 12) {
                Button {
                    vm.resumeGame()
                } label: {
                    Text("Resume")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("resume")

                Button {
                    vm.restart()
                } label: {
                    Text("Restart")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("restart")
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

private struct GameToolbar: View {
    @Bindable var vm: GameViewModel
    let showCheck: Bool

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton("Undo", systemImage: "arrow.uturn.backward", disabled: !vm.canUndo) {
                vm.undo()
            }
            toolbarButton("Erase", systemImage: "eraser") {
                vm.erase()
            }
            // Chain layers: what-if sheets stacked on the real game.
            toolbarButton(
                "Layer",
                systemImage: "square.3.layers.3d",
                disabled: vm.layers.count >= GameViewModel.layerLimit
            ) {
                vm.addLayer()
            }
            // Pencil: tap toggles mode, long-press fills all candidates.
            VStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.title3)
                    .symbolVariant(vm.pencilMode ? .circle.fill : .none)
                Text(vm.pencilMode ? "Pencil On" : "Pencil")
                    .font(.caption2)
            }
            .foregroundStyle(vm.pencilMode ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { vm.pencilMode.toggle() }
            .onLongPressGesture { vm.fillAllCandidates() }
            .accessibilityElement()
            .accessibilityLabel(vm.pencilMode ? "Pencil mode on" : "Pencil mode off")
            .accessibilityHint("Double tap to toggle. Long press to fill all candidates.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("pencil")

            toolbarButton("Hint", systemImage: "lightbulb") {
                vm.hint()
            }
            if showCheck {
                toolbarButton("Check", systemImage: "checkmark.circle") {
                    vm.checkNow()
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func toolbarButton(
        _ title: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityIdentifier(title.lowercased())
    }
}
