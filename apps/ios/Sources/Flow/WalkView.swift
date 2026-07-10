import SwiftUI
import PhotosUI

// Live capture — the walk. Everything readable at arm's length; controls
// glove-sized in the thumb zone.

struct WalkView: View {
    @Bindable var model: AppModel
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                RecBanner(timer: model.isPaused ? "PAUSED" : model.elapsedLabel)
            }

            MetaStrip(
                left: model.trade.site,
                right: model.walkMode == .demo ? "DEMO WALK — SCRIPTED" : "REC — ON-DEVICE STT",
                warn: model.walkMode == .demo
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.transcript)
                        .font(Theme.F.mono(11.5))
                        .foregroundStyle(Theme.C.ink60)
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Caret(height: 13)
                }
                .padding(.horizontal, Theme.S.screenPad)
                .padding(.vertical, 12)
            }
            .frame(height: 168)
            .defaultScrollAnchor(.bottom)

            SectionHead(left: "CAPTURED", right: "\(model.items.count) ITEMS")
                .overlay(alignment: .top) { Theme.C.ink.frame(height: 1.5) }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.items) { item in
                        CapturedRow(item: item)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }

            VStack(spacing: 12) {
                if model.isPaused {
                    Button { model.discardWalk() } label: {
                        Text("DISCARD WALK — NOTHING SAVED")
                            .font(Theme.F.mono(10, .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.C.redTag)
                            .frame(height: 30)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                } else {
                    Waveform()
                }
                HStack(spacing: 9) {
                    // One tap, zero confirm: camera on device, picker on sim.
                    // The shot pins to the item being spoken (see addPhoto).
                    if CameraCapture.isAvailable {
                        Button { showCamera = true } label: { PhotoSquareButton() }
                            .buttonStyle(.plain)
                    } else {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            PhotoSquareButton()
                        }
                        .buttonStyle(.plain)
                    }
                    Button { model.togglePause() } label: {
                        Text(model.isPaused ? "RESUME" : "PAUSE")
                            .font(Theme.F.ui(13.5, .bold))
                            .tracking(1.1)
                            .foregroundStyle(Theme.C.ink)
                            .frame(width: 96)
                            .frame(height: Theme.S.buttonHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.S.radius)
                                    .stroke(Theme.C.ink, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    // DONE is finishable once ANYTHING has been captured —
                    // transcript OR extracted items (issue #168). On a voice
                    // walk the live board lags the speech (batched extraction),
                    // and finish() runs a full extraction pass anyway, so
                    // gating on items alone stranded the user on a stuck screen
                    // whenever items hadn't landed yet. Transcript-or-items.
                    let nothingCaptured = model.transcript.isEmpty && model.items.isEmpty
                    Button { model.finishWalk() } label: { DoneButton() }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .disabled(nothingCaptured)
                        .opacity(nothingCaptured ? 0.4 : 1)
                }
            }
            .padding(.horizontal, Theme.S.screenPad)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .overlay(alignment: .top) { Theme.C.hairline.frame(height: 1) }
        }
        .background(Theme.C.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { data in model.addPhoto(data) }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    model.addPhoto(data)
                }
                pickerItem = nil
            }
        }
    }
}
