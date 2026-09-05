import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.26, green: 0.30, blue: 0.27)
    static let muted = Color(red: 0.54, green: 0.56, blue: 0.51)
    static let paper = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let line = Color(red: 0.88, green: 0.88, blue: 0.82)
    static let green = Color(red: 0.27, green: 0.46, blue: 0.36)
    static let mint = Color(red: 0.88, green: 0.92, blue: 0.85)
    static let amber = Color(red: 0.70, green: 0.44, blue: 0.23)
}

func number(_ value: Double) -> String {
    if value >= 1_000_000 { return String(format: "%.1fm", value / 1_000_000) }
    if value >= 10_000 { return String(format: "%.1fk", value / 1_000) }
    return String(format: "%.0f", floor(value))
}

struct CompanionRoot: View {
    @ObservedObject var store: GameStore
    var body: some View {
        Group {
            switch store.settings.mode {
            case .room: RoomView(store: store)
            case .pet: PetView(store: store)
            case .compact: CompactView(store: store)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }
}

private struct RoomView: View {
    @ObservedObject var store: GameStore
    @State private var showHelp = false
    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: 28)
            Spacer().frame(height: 10)
            scene.frame(height: 126)
            Spacer().frame(height: 10)
            stats.frame(height: 42)
            Spacer().frame(height: 11)
            tabs.frame(height: 28)
            Spacer().frame(height: 9)
            Group {
                if showHelp { help }
                else if store.selectedTab == 0 { companion }
                else if store.selectedTab == 1 { workshop }
                else if store.selectedTab == 2 { decorations }
                else { FishingView(store: store) }
            }.frame(height: 118, alignment: .top)
            Spacer(minLength: 0)
            footer.frame(height: 18)
        }
        .padding(14)
        .frame(width: 320, height: 452)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1))
        .overlay(alignment: .top) {
            if !store.toast.isEmpty {
                Text(store.toast)
                    .font(.system(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: 264)
                    .background(Palette.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 53)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "pawprint.fill").foregroundStyle(Palette.green).font(.system(size: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text("角落有喵").font(.system(size: 13, weight: .bold))
                    Text("A LITTLE COMPANY").font(.system(size: 6.5, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
            .overlay(WindowDragHandle())
            .help("拖动这里移动小窗")
            IconButton(symbol: "pawprint", label: "切换透明桌宠") { store.setMode(.pet) }
            IconButton(symbol: "minus", label: "收起为迷你状态条") { store.setMode(.compact) }
            IconButton(symbol: "xmark", label: "隐藏窗口，继续挂机") { store.onHide?() }
        }
    }

    private var scene: some View {
        ZStack(alignment: .topLeading) {
            CatScene(activity: store.game.activity.rawValue, decor: store.game.equippedDecor, level: store.game.level, reaction: store.reaction)
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Palette.green).frame(width: 4, height: 4)
                        Text(activityTitle).font(.system(size: 8, weight: .semibold))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Palette.paper.opacity(0.88), in: Capsule())
                    Spacer()
                    Text("LV.\(store.game.level)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Palette.paper.opacity(0.88), in: Capsule())
                }
                Spacer()
                if store.offlineDew > 0 {
                    Button {
                        store.offlineDew = 0
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "moon.stars")
                            Text("不在的时候，小猫攒了 \(number(store.offlineDew)) 露珠")
                            Image(systemName: "checkmark")
                        }.font(.system(size: 8, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Palette.paper.opacity(0.96), in: Capsule())
                    }.buttonStyle(.plain).help("离线收益已自动到账，点击收起")
                }
            }.padding(9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line.opacity(0.55)))
        .contentShape(Rectangle())
        .onTapGesture { store.pet() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("小猫的花园")
        .accessibilityAction(named: "摸摸小猫") { store.pet() }
        .help("点一下小猫，摸摸它")
    }

    private var stats: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "drop.fill").font(.system(size: 14)).foregroundStyle(Palette.green)
                Text(number(store.game.dew)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                Text("露珠").font(.system(size: 9)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                Text(String(format: "+%.1f / 分钟", store.game.productionPerMinute))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.green)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(Palette.amber)
                    Text("亲密 \(store.game.bond)")
                    Text("·")
                    Text("心情 \(Int(store.game.mood))")
                }.font(.system(size: 8)).foregroundStyle(Palette.muted)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 3) {
            tabButton("陪伴", symbol: "heart", index: 0)
            tabButton("升级", symbol: "leaf", index: 1)
            tabButton("小物", symbol: "square.grid.2x2", index: 2)
            tabButton("钓鱼", symbol: "fish", index: 3)
        }.padding(3).background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line.opacity(0.75)))
    }

    private func tabButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { store.selectedTab = index; showHelp = false } label: {
            HStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 9)); Text(title).font(.system(size: 10, weight: .semibold)) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(store.selectedTab == index && !showHelp ? Palette.green : Palette.muted)
                .background(store.selectedTab == index && !showHelp ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain)
    }

    private var companion: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                activityButton(.garden, name: "照料", symbol: "leaf")
                activityButton(.explore, name: "探索", symbol: "sparkle.magnifyingglass")
                activityButton(.nap, name: "打盹", symbol: "moon.zzz")
            }.frame(height: 30)
            HStack(spacing: 8) {
                Button { store.pet() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw")
                        Text("摸摸")
                        Spacer()
                        Text(store.game.petCooldownRemaining(now: store.now) > 0 ? "\(Int(ceil(store.game.petCooldownRemaining(now: store.now))))s" : "+亲密")
                            .font(.system(size: 8)).opacity(0.65)
                    }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 30)
                }.buttonStyle(SoftButtonStyle())
                Button { store.feed() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "fish")
                        Text("喂食")
                        Spacer()
                        Text(store.game.feedCooldownRemaining(now: store.now) > 0 ? "\(Int(ceil(store.game.feedCooldownRemaining(now: store.now))))s" : "12 露珠")
                            .font(.system(size: 8)).opacity(0.65)
                    }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 30)
                }.buttonStyle(SoftButtonStyle())
                    .disabled(store.game.dew < 12 || store.game.feedCooldownRemaining(now: store.now) > 0)
            }
            VStack(spacing: 4) {
                HStack {
                    Text("\(levelName) · Lv.\(store.game.level)")
                    Spacer()
                    Text("\(number(store.game.xpInLevel)) / \(number(store.game.xpForNextLevel))")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                }.font(.system(size: 8)).foregroundStyle(Palette.muted)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line.opacity(0.75))
                        Capsule().fill(Palette.green.opacity(0.7)).frame(width: geometry.size.width * min(1, max(0, store.game.xpInLevel / max(1, store.game.xpForNextLevel))))
                    }
                }.frame(height: 3)
                Text(store.game.nextUnlock).font(.system(size: 8)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            }
        }
    }

    private func activityButton(_ kind: ActivityKind, name: String, symbol: String) -> some View {
        let selected = store.game.activity == kind
        let unlocked = store.game.activityUnlocked(kind)
        return Button { store.setActivity(kind) } label: {
            HStack(spacing: 4) {
                Image(systemName: unlocked ? symbol : "lock").font(.system(size: 9))
                Text(unlocked ? name : "探索 Lv.2").font(.system(size: 9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(selected ? Palette.green : Palette.muted)
            .background(selected ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Palette.green.opacity(0.2) : Palette.line.opacity(0.8)))
        }.buttonStyle(.plain).disabled(!unlocked)
            .help(activityDescription(kind))
    }

    private var workshop: some View {
        VStack(spacing: 5) {
            upgradeRow(.planter, name: UpgradeKind.planter.title, detail: UpgradeKind.planter.detail, symbol: "leaf")
            upgradeRow(.watering, name: UpgradeKind.watering.title, detail: UpgradeKind.watering.detail, symbol: "drop")
            upgradeRow(.cushion, name: UpgradeKind.cushion.title, detail: UpgradeKind.cushion.detail, symbol: "moon")
        }
    }

    private func upgradeRow(_ kind: UpgradeKind, name: String, detail: String, symbol: String) -> some View {
        let unlocked = store.game.upgradeUnlocked(kind)
        let price = store.game.upgradeCost(kind)
        let level = store.game.upgradeLevel(kind)
        let maxed = level >= GameState.maximumUpgradeLevel
        return HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Palette.green)
                .frame(width: 27, height: 30).background(Palette.mint.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(name).font(.system(size: 10, weight: .semibold))
                    Text("\(level)").font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.muted)
                }
                Text(detail).font(.system(size: 7.5)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Button { store.buy(kind) } label: {
                HStack(spacing: 3) {
                    if !unlocked { Image(systemName: "lock.fill") }
                    else if !maxed { Image(systemName: "drop.fill") }
                    Text(unlocked ? (!maxed ? number(price) : "已满级") : "Lv.\(kind == .watering ? 2 : 3)")
                }.font(.system(size: 9, weight: .semibold, design: .rounded))
                    .frame(width: 60, height: 27)
            }.buttonStyle(SoftButtonStyle())
                .disabled(!unlocked || maxed || store.game.dew < price)
                .accessibilityLabel("升级\(name)，\(maxed ? "已满级" : unlocked ? number(price) + "露珠" : "尚未解锁")")
        }.frame(height: 34)
    }

    private var decorations: some View {
        ScrollView(.vertical) {
            VStack(spacing: 5) {
                ForEach(GameState.decorations) { decor in
                    let owned = store.game.unlockedDecor.contains(decor.id)
                    let equipped = store.game.equippedDecor == decor.id
                    let unlocked = store.game.level >= decor.requiredLevel
                    Button { store.chooseDecor(decor.id) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: decor.symbol).font(.system(size: 12)).foregroundStyle(Palette.amber).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(decor.name).font(.system(size: 10, weight: .semibold))
                                Text(decor.detail).font(.system(size: 7.5)).foregroundStyle(Palette.muted).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(equipped ? "已摆好" : (owned ? "摆上" : (unlocked ? "\(number(decor.price)) 露珠" : "Lv.\(decor.requiredLevel)")))
                                .font(.system(size: 8, weight: .semibold)).foregroundStyle(equipped ? Palette.green : Palette.muted)
                        }.padding(.horizontal, 7).frame(height: 34)
                            .background(equipped ? Palette.mint.opacity(0.55) : .white.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).disabled(!owned && (!unlocked || store.game.dew < decor.price))
                }
            }
        }.scrollIndicators(.visible)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(store.saveError ? Color.orange : Palette.green.opacity(0.65)).frame(width: 4, height: 4)
            Text(store.saveError ? "存档异常" : "慢慢长大，悄悄陪你")
                .font(.system(size: 7.5)).foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
            IconButton(symbol: store.settings.alwaysOnTop ? "pin.fill" : "pin.slash", label: "窗口置顶") { store.togglePin() }
            IconButton(symbol: store.settings.dimmed ? "circle.lefthalf.filled" : "circle", label: "低调透明：切换 72% 不透明度") { store.toggleDim() }
            IconButton(symbol: showHelp ? "questionmark.circle.fill" : "questionmark.circle", label: "玩法与快捷键") { showHelp.toggle() }
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("小猫会自己慢慢忙碌。")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.green)
            Text("照料攒露珠 · 探索更快升级 · 钓鱼赚奖励")
            Text("拖动标题移动；桌宠模式拖动脚下的小横线。")
            Text(store.hotkeyAvailable ? "⌘⇧H 随时隐藏 / 唤回；Esc 隐藏。" : "⌘⇧H 已被占用，请用菜单栏爪印唤回。")
            Text("菜单栏爪印可唤回；右键可切换模式或退出。")
            Text("自动存档 · 离线收益上限 8 小时")
                .foregroundStyle(Palette.green)
        }.font(.system(size: 8.5)).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activityTitle: String {
        switch store.game.activity {
        case .garden: return "小猫正在照料花园"
        case .explore: return "小猫正在窗边探索"
        case .nap: return "嘘，小猫睡着了"
        }
    }
    private var levelName: String { store.game.level < 3 ? "初来乍到" : store.game.level < 6 ? "熟悉的陪伴" : "窗边老朋友" }
    private func activityDescription(_ kind: ActivityKind) -> String {
        switch kind {
        case .garden: return "照料花园：露珠产出最多，稳定获得经验"
        case .explore: return "窗边探索：露珠略少，经验更多，Lv.2 解锁"
        case .nap: return "安心打盹：恢复心情，依然有少量露珠和经验"
        }
    }
}

private struct CompactView: View {
    @ObservedObject var store: GameStore
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.dotted").font(.system(size: 11)).foregroundStyle(Palette.green)
                .frame(width: 17, height: 26)
                .overlay(WindowDragHandle(onDoubleClick: { store.setMode(.room) }))
                .help("拖动状态条")
            Button { store.setMode(.room) } label: {
                HStack(spacing: 5) {
                    Text("\(number(store.game.dew))").font(.system(size: 11, weight: .semibold, design: .monospaced)).monospacedDigit()
                    Text("+\(String(format: "%.1f", store.game.productionPerMinute))/m").font(.system(size: 7, design: .monospaced)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("打开小屋")
        }.padding(.horizontal, 10)
            .frame(width: 164, height: 34)
            .background(Palette.paper.opacity(0.97), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
            .contextMenu { modeMenu(store) }
    }
}

private struct PetView: View {
    @ObservedObject var store: GameStore
    @State private var hovering = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IconButton(symbol: "house", label: "打开小屋") { store.setMode(.room) }
                IconButton(symbol: "minus", label: "收起状态条") { store.setMode(.compact) }
            }.frame(height: 20).opacity(hovering ? 1 : 0)
            Button { store.pet() } label: {
                PixelCat(activity: store.game.activity.rawValue, reaction: store.reaction, scale: 1.1)
                    .frame(width: 96, height: 78)
            }.buttonStyle(.plain).help("摸摸小猫 · 右键打开菜单")
            Capsule().fill(Palette.ink.opacity(hovering ? 0.45 : 0.16)).frame(width: 25, height: 4)
                .frame(width: 70, height: 18)
                .contentShape(Rectangle())
                .overlay(WindowDragHandle(onDoubleClick: { store.setMode(.room) }))
                .help("拖动小猫，双击打开小屋")
        }.frame(width: 120, height: 120)
            .onHover { hovering = $0 }
            .contextMenu { modeMenu(store) }
    }
}

@MainActor @ViewBuilder
private func modeMenu(_ store: GameStore) -> some View {
    Button("打开小屋") { store.setMode(.room) }
    Button("透明桌宠") { store.setMode(.pet) }
    Button("迷你状态条") { store.setMode(.compact) }
    Divider()
    Button(store.settings.alwaysOnTop ? "取消置顶" : "窗口置顶") { store.togglePin() }
    Button("低调透明") { store.toggleDim() }
    Button("隐藏窗口  ⌘⇧H") { store.onHide?() }
    Divider()
    Button("退出角落有喵") { store.onQuit?() }
}

private struct IconButton: View {
    var symbol: String
    var label: String
    var action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .medium))
                .foregroundStyle(hovering ? Palette.green : Palette.muted)
                .frame(width: 20, height: 22)
                .background(hovering ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label).onHover { hovering = $0 }
    }
}

private struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Palette.green : Palette.muted.opacity(0.7))
            .background(isEnabled ? Palette.mint.opacity(configuration.isPressed ? 1 : 0.65) : Palette.line.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.green.opacity(isEnabled ? 0.15 : 0.04)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
