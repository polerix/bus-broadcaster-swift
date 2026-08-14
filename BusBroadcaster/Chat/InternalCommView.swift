import SwiftUI

struct InternalCommView: View {
    @EnvironmentObject var turnQueue: TurnQueue

    var body: some View {
        VStack(spacing: 0) {
            header
            internalScrollArea
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .overlay(Rectangle().frame(width: 1).foregroundColor(.white.opacity(0.1)), alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text("📟 INTERNAL COMMS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.orange.opacity(0.8))
            
            Spacer()
            
            Toggle(isOn: $turnQueue.isInternalSpeakerActive) {
                Text("SPEAKER")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(turnQueue.isInternalSpeakerActive ? .orange : .white.opacity(0.3))
            }
            .toggleStyle(.switch)
            .scaleEffect(0.6)
            .tint(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }

    private var internalScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(turnQueue.internalMessages) { msg in
                        InternalMessageRow(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: turnQueue.internalMessages.count) { _ in
                if let last = turnQueue.internalMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct InternalMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(message.character.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(message.nameColor.opacity(0.8))
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            Text(message.text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 2)
    }
}
