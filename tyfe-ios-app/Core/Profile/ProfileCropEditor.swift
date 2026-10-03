import SwiftUI

struct ProfileCropEditor: View {
    let presenter: ProfilePresenter
    @State private var gestureStart: ProfileCropTransform?

    var body: some View {
        NavigationStack {
            ZStack {
                TyfeEditorialPalette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        Text("Drag to position your photo. Pinch to zoom. The circle previews how your square photo will appear.")
                            .font(TyfeTypography.interface)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                        if let crop = presenter.crop {
                            cropCanvas(crop)
                            HStack {
                                Button("Zoom out") {
                                    presenter.onCropChanged(zoom: crop.transform.zoom - 0.25, offset: crop.transform.offset)
                                }
                                .disabled(crop.transform.zoom <= 1)
                                Spacer()
                                Button("Zoom in") {
                                    presenter.onCropChanged(zoom: crop.transform.zoom + 0.25, offset: crop.transform.offset)
                                }
                                .disabled(crop.transform.zoom >= 5)
                            }
                            .frame(minHeight: 44)
                            Button("Reset crop") { presenter.onCropChanged(zoom: 1, offset: .zero) }
                                .frame(minHeight: 44)
                        }
                        if let message = presenter.errorMessage {
                            Text(message).font(TyfeTypography.interface)
                        }
                        if let message = presenter.accountMessage {
                            Text(message).font(TyfeTypography.interface)
                        }
                        TyfeActionButtonView(
                            title: "Use photo", systemImage: "checkmark", role: .primary,
                            onTap: { presenter.onUsePhotoPressed() }
                        )
                        .disabled(!presenter.isEditingAccount)
                        .accessibilityIdentifier("profile-use-photo")
                    }
                    .padding(TyfeSpacing.control)
                }
            }
            .navigationTitle("Crop photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { presenter.onCancelCropPressed() }
                }
            }
        }
    }

    private func cropCanvas(_ crop: ProfilePhotoCrop) -> some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let rect = crop.transform.imageRect(imageSize: crop.image.size, viewport: side)
            ZStack {
                Image(uiImage: crop.image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                CropCircleMask()
                    .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                Circle().stroke(.white, lineWidth: 2)
                    .padding(1)
            }
            .frame(width: side, height: side)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .simultaneously(with: MagnifyGesture())
                    .onChanged { value in
                        guard side > 0 else { return }
                        if gestureStart == nil { gestureStart = crop.transform }
                        guard let start = gestureStart else { return }
                        let translation = value.first?.translation ?? .zero
                        let zoom = start.zoom * (value.second?.magnification ?? 1)
                        let offset = CGSize(
                            width: start.offset.width + translation.width / side,
                            height: start.offset.height + translation.height / side
                        )
                        presenter.onCropChanged(zoom: zoom, offset: offset)
                    }
                    .onEnded { _ in gestureStart = nil }
            )
            .accessibilityLabel("Photo crop preview")
            .accessibilityHint("Drag to reposition. Pinch, or use the zoom buttons, to change the crop.")
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(Rectangle().stroke(TyfeEditorialPalette.border, lineWidth: TyfeStroke.standard))
    }
}

private struct CropCircleMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: rect)
        return path
    }
}
