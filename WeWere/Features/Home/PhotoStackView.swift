import SwiftUI

struct PhotoStackView: View {
    let photos: [StackPhoto]
    let onTap: (StackPhoto) -> Void

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isLocked = false

    var body: some View {
        VStack(spacing: WeWereSpacing.sm) {
            ZStack {
                // Render cards for indices around current, keyed by photo ID so they're stable
                ForEach(visibleCards, id: \.photo.id) { card in
                    polaroidCard(for: card.photo)
                        .zIndex(card.zIndex)
                        .offset(x: card.offset + (card.isTop ? dragOffset : 0))
                        .rotationEffect(.degrees(card.rotation + (card.isTop ? Double(dragOffset) / 25 : 0)))
                        .scaleEffect(card.scale)
                        .opacity(card.opacity)
                        .allowsHitTesting(card.isTop && !isLocked)
                        .onTapGesture {
                            guard card.isTop, !isLocked else { return }
                            onTap(card.photo)
                        }
                        .gesture(card.isTop ? dragGesture : nil)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight + 30)
            .padding(.vertical, WeWereSpacing.xs)

            Text("\(currentIndex + 1) / \(photos.count)")
                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                .foregroundStyle(WeWereColors.outline)
                .tracking(1)
        }
    }

    // MARK: - Visible cards model

    private struct CardInfo {
        let photo: StackPhoto
        let isTop: Bool
        let zIndex: Double
        let offset: CGFloat
        let rotation: Double
        let scale: CGFloat
        let opacity: Double
    }

    private var visibleCards: [CardInfo] {
        var cards: [CardInfo] = []

        // Determine which card to show underneath based on drag direction
        let nextIndex: Int
        if dragOffset < -10 {
            // Swiping left → show next photo underneath
            nextIndex = wrappedIndex(currentIndex + 1)
        } else if dragOffset > 10 {
            // Swiping right → show previous photo underneath
            nextIndex = wrappedIndex(currentIndex - 1)
        } else {
            // Not dragging → default to next
            nextIndex = wrappedIndex(currentIndex + 1)
        }

        // Card 3 (deepest decoration)
        if photos.count > 2 {
            let deepIndex = dragOffset > 10
                ? wrappedIndex(currentIndex - 2)
                : wrappedIndex(currentIndex + 2)
            cards.append(CardInfo(
                photo: photos[deepIndex],
                isTop: false, zIndex: 0, offset: 8,
                rotation: 4, scale: 0.92, opacity: 0.25
            ))
        }

        // Card 2 (the one revealed underneath)
        if photos.count > 1 {
            cards.append(CardInfo(
                photo: photos[nextIndex],
                isTop: false, zIndex: 1, offset: -5,
                rotation: -2.5, scale: 0.97, opacity: 0.6
            ))
        }

        // Card 1 (top / current)
        cards.append(CardInfo(
            photo: photos[currentIndex],
            isTop: true, zIndex: 2, offset: 0,
            rotation: 0, scale: 1.0, opacity: 1.0
        ))

        return cards
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isLocked else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !isLocked else { return }
                let threshold: CGFloat = 60
                let velocity = value.predictedEndTranslation.width - value.translation.width

                if value.translation.width < -threshold || velocity < -200 {
                    dismissCard(direction: -1, nextDelta: 1)
                } else if value.translation.width > threshold || velocity > 200 {
                    dismissCard(direction: 1, nextDelta: -1)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismissCard(direction: CGFloat, nextDelta: Int) {
        isLocked = true

        // Animate top card off screen
        withAnimation(.easeIn(duration: 0.15)) {
            dragOffset = direction * 400
        }

        // Swap index after card is fully off screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            // Change the index -- since cards are keyed by photo.id,
            // the OLD top card will be removed from the ForEach,
            // and the card that was "next" will become the new top.
            // No flash because SwiftUI matches by ID, not position.
            currentIndex = wrappedIndex(currentIndex + nextDelta)
            dragOffset = 0
            isLocked = false
        }
    }

    // MARK: - Polaroid Card

    private func polaroidCard(for photo: StackPhoto) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: photo.url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: photoWidth, height: photoHeight)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(WeWereColors.surfaceContainerHigh)
                        .frame(width: photoWidth, height: photoHeight)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(WeWereColors.outline)
                        }
                case .empty:
                    Rectangle()
                        .fill(WeWereColors.surfaceContainer)
                        .frame(width: photoWidth, height: photoHeight)
                        .overlay {
                            ProgressView()
                                .tint(WeWereColors.outline)
                        }
                @unknown default:
                    Rectangle()
                        .fill(WeWereColors.surfaceContainer)
                        .frame(width: photoWidth, height: photoHeight)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(photo.photographerName)
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                    .foregroundStyle(Color(hex: "555555"))
                    .lineLimit(1)

                Text(formattedDate(photo.date))
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                    .foregroundStyle(Color(hex: "919191"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.white)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }

    // MARK: - Layout

    private var cardWidth: CGFloat { 260 }
    private var photoWidth: CGFloat { cardWidth - 24 }
    private var photoHeight: CGFloat { photoWidth * (4.0 / 3.0) }
    private var cardHeight: CGFloat { photoHeight + 12 + 8 + 20 + 16 }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = photos.count
        guard count > 0 else { return 0 }
        return ((index % count) + count) % count
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy  h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Empty State

struct PhotoStackEmptyView: View {
    var body: some View {
        VStack(spacing: WeWereSpacing.sm) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(WeWereColors.surfaceContainerHigh)
                    .frame(width: 180, height: 220)
                    .overlay {
                        Image(systemName: "film.stack")
                            .font(.system(size: 36))
                            .foregroundStyle(WeWereColors.outlineVariant)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)

                Spacer().frame(height: 32)
            }
            .frame(width: 204)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
            )
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            Text("SWIPE THROUGH THE PAST")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 20))
                .foregroundStyle(.white)
                .tracking(2)
                .multilineTextAlignment(.center)
                .padding(.top, WeWereSpacing.xs)

            Text("Relive your circle's best moments")
                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                .foregroundStyle(Color(hex: "#919191"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WeWereSpacing.md)
    }
}
