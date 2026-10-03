import SwiftUI

/// Profile identity uses the preferred cached name, never a different account's cache.
enum ProfileDisplayIdentity {
    static func name(user: UserModel?, auth: UserAuthInfo?) -> String? {
        let candidates = [user?.submittedName, user?.displayName, auth?.displayName, user?.firstName]
        return candidates.compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = ProfileValidation.trimmedName(value)
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }

    static func initials(name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct ProfileAvatarView: View {
    let initials: String
    var photoURL: URL?
    var draftImage: UIImage?
    var size: CGFloat = 64
    @State private var localImage: UIImage?
    @State private var localImageURL: URL?

    var body: some View {
        Group {
            if let draftImage {
                Image(uiImage: draftImage)
                    .resizable()
                    .scaledToFill()
            } else if let photoURL, photoURL.isFileURL {
                if let localImage, localImageURL == photoURL {
                    Image(uiImage: localImage).resizable().scaledToFill()
                } else {
                    fallback
                }
            } else if let photoURL {
                // ImageLoaderView has no failure phase; expired signed URLs must show initials.
                AsyncImage(url: photoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(TyfeEditorialPalette.border, lineWidth: TyfeStroke.standard))
        .accessibilityHidden(true)
        .task(id: photoURL) {
            localImage = nil
            localImageURL = nil
            if let photoURL, photoURL.isFileURL {
                localImage = UIImage(contentsOfFile: photoURL.path)
                localImageURL = photoURL
            }
        }
    }

    private var fallback: some View {
        Text(initials)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(TyfeEditorialPalette.ink)
            .background(TyfeEditorialPalette.canvas)
    }
}
