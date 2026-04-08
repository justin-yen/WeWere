import SwiftUI

struct ReactionBar: View {
    let myReactions: Set<Reaction.ReactionEmoji>
    var reactionCounts: [Reaction.ReactionEmoji: Int] = [:]
    var reactorNames: [Reaction.ReactionEmoji: [String]] = [:]
    let onToggle: (Reaction.ReactionEmoji) -> Void

    @State private var showingReactorSheet: ReactorSheet?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Reaction.ReactionEmoji.allCases, id: \.self) { emoji in
                VStack(spacing: 2) {
                    Text(emoji.display)
                        .font(.system(size: 28))
                        .opacity(myReactions.contains(emoji) ? 1.0 : 0.4)
                        .scaleEffect(myReactions.contains(emoji) ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: myReactions.contains(emoji))

                    let count = reactionCounts[emoji] ?? 0
                    Text(count > 0 ? "\(count)" : " ")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                        .foregroundStyle(count > 0 ? WeWereColors.onSurfaceVariant : .clear)
                }
                .frame(height: 50)
                .onTapGesture {
                    onToggle(emoji)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if let names = reactorNames[emoji], !names.isEmpty {
                        showingReactorSheet = ReactorSheet(emoji: emoji)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $showingReactorSheet) { sheet in
            reactorsList(for: sheet.emoji)
                .presentationDetents([.medium, .fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }

    private func reactorsList(for emoji: Reaction.ReactionEmoji) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(emoji.display)
                    .font(.system(size: 32))
                Text("REACTIONS")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 14))
                    .tracking(2)
                    .foregroundStyle(WeWereColors.onSurface)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Names list
            let names = reactorNames[emoji] ?? []
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(WeWereColors.secondaryContainer)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                        .foregroundStyle(.white)
                                )

                            Text(name)
                                .font(.custom(WeWereFontFamily.jakartaRegular, size: 15))
                                .foregroundStyle(WeWereColors.onSurface)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(WeWereColors.surface)
    }
}

struct ReactorSheet: Identifiable {
    let id = UUID()
    let emoji: Reaction.ReactionEmoji
}
