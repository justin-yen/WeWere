import SwiftUI

struct ReactionBar: View {
    let reactionCounts: [Reaction.ReactionEmoji: Int]
    let myReactions: Set<Reaction.ReactionEmoji>
    let onToggle: (Reaction.ReactionEmoji) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Reaction.ReactionEmoji.allCases, id: \.self) { emoji in
                Button {
                    onToggle(emoji)
                } label: {
                    VStack(spacing: 2) {
                        Text(emoji.display)
                            .font(.system(size: 20))

                        Text("\(reactionCounts[emoji, default: 0])")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(myReactions.contains(emoji)
                                  ? WeWereColors.secondaryContainer
                                  : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
