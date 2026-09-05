import SwiftUI

struct FishingView: View {
    @ObservedObject var store: GameStore
    private let green = Color(red: 0.27, green: 0.46, blue: 0.36)
    private let muted = Color(red: 0.54, green: 0.56, blue: 0.51)
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "fish").foregroundStyle(green)
                Text("窗边垂钓").font(.system(size: 10, weight: .semibold))
                Spacer()
                if let session = store.fishingSession, !session.finished {
                    Text("第 \(session.catches.count + 1) / 3 竿")
                } else { Text("最佳 \(store.fishingRecord.bestScore) / 6") }
            }.font(.system(size: 8)).foregroundStyle(muted)
            if let session = store.fishingSession, !session.finished {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5).fill(green.opacity(0.10))
                            RoundedRectangle(cornerRadius: 3).fill(green.opacity(0.35))
                                .frame(width: width * session.targetWidth)
                                .offset(x: width * (session.target - session.targetWidth / 2))
                            Rectangle().fill(green.opacity(0.7)).frame(width: width * 0.08)
                                .offset(x: width * (session.target - 0.04))
                            Capsule().fill(Color(red: 0.75, green: 0.39, blue: 0.20)).frame(width: 4, height: 26)
                                .offset(x: min(width - 4, width * session.cursor(at: context.date)))
                        }
                    }
                }.frame(height: 26).accessibilityLabel("移动浮标，绿色区域收竿得分，中间深绿区域双倍")
                Button { store.castFishing() } label: {
                    HStack {
                        Text("收竿！")
                        Spacer()
                        Text("SPACE").font(.system(size: 7, weight: .semibold, design: .monospaced)).opacity(0.65)
                    }.padding(.horizontal, 12).frame(height: 28)
                }.buttonStyle(FishButtonStyle()).keyboardShortcut(.space, modifiers: [])
                Text(catchHint(session)).font(.system(size: 8)).foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if let session = store.fishingSession, session.finished {
                    HStack(spacing: 8) {
                        ForEach(Array(session.catches.enumerated()), id: \.offset) { _, score in
                            Image(systemName: score == 2 ? "sparkles" : score == 1 ? "fish.fill" : "water.waves")
                                .foregroundStyle(score > 0 ? green : muted.opacity(0.5))
                        }
                        Spacer()
                        Text("+\(3 + session.score * 3) 露珠  +\(4 + session.score * 2) 经验")
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(green)
                    }.frame(height: 26)
                } else {
                    Text("看准绿色区域收竿，正中靶心有双倍分。")
                        .font(.system(size: 9)).foregroundStyle(muted).frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                }
                Button { store.startFishing() } label: {
                    HStack {
                        Text(store.fishingCooldown > 0 ? "鱼群休息中 · \(Int(ceil(store.fishingCooldown)))s" : "抛竿，钓一会儿")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }.padding(.horizontal, 12).frame(height: 28)
                }.buttonStyle(FishButtonStyle()).disabled(store.fishingCooldown > 0)
                Text("每局三竿 · 每竿限时 6s · 离开会结束本局")
                    .font(.system(size: 8)).foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.onDisappear { store.leaveFishing() }
    }
    private func catchHint(_ session: FishingSession) -> String {
        guard let last = session.catches.last else { return "浮标进绿区时点击收竿，也可以按空格" }
        return last == 2 ? "漂亮！正中靶心 +2 分，继续下一竿" : last == 1 ? "钓到了！+1 分，再瞄准中间一点" : "小鱼溜走了，下一竿慢慢来"
    }
}

private struct FishButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 10, weight: .semibold))
            .foregroundStyle(enabled ? .white : Color.gray)
            .background(enabled ? Color(red: 0.27, green: 0.46, blue: 0.36).opacity(configuration.isPressed ? 0.75 : 1) : Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}
